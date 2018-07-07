//
//  main.m
//  SCKillerHelper
//
//  Created by Charles Stigler on 9/21/14.
//
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <unistd.h>
#import "BlockManager.h"

#define LOG_FILE @"~/Documents/SelfControl-Killer.log"

int main(int argc, char* argv[]) {
	@autoreleasepool {

		if(geteuid()) {
			NSLog(@"ERROR: Helper tool must be run as root.");
			exit(EXIT_FAILURE);
		}

		if(argv[1] == NULL) {
			NSLog(@"ERROR: Not enough arguments");
			exit(EXIT_FAILURE);
		}

		int controllingUID = [@(argv[1]) intValue];
		NSString* logFilePath = [LOG_FILE stringByExpandingTildeInPath];

		NSMutableString* log = [NSMutableString stringWithString: @"===SelfControl-Killer Log File===\n\n"];

		/* FIRST TASK: print debug info */

		// print SC version:
		NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
		NSString* version = [infoDict objectForKey:@"CFBundleShortVersionString"];
		[log appendFormat: @"SelfControl Version: %@\n", version];

		// print system version
		[log appendFormat: @"System Version: Mac OS X %@", [[NSProcessInfo processInfo] operatingSystemVersionString]];

		// print launchd daemons
		int status;
		NSTask* task;
		task = [[NSTask alloc] init];
		[task setLaunchPath: @"/bin/launchctl"];
		NSArray* args = @[@"list"];
		[task setArguments:args];
		NSPipe* inPipe = [[NSPipe alloc] init];
		NSFileHandle* readHandle = [inPipe fileHandleForReading];
		[task setStandardOutput: inPipe];
		[task launch];
		NSString* daemonList = [[NSString alloc] initWithData:[readHandle readDataToEndOfFile]
													 encoding: NSUTF8StringEncoding];
		close([readHandle fileDescriptor]);
		[task waitUntilExit];
		status = [task terminationStatus];
		if(daemonList) {
			[log appendFormat: @"Launchd daemons loaded:\n\n%@\n", daemonList];
		}

		// print defaults
		seteuid(controllingUID);
		task = [[NSTask alloc] init];
		[task setLaunchPath: @"/usr/bin/defaults"];
		args = @[@"read", @"org.eyebeam.SelfControl"];
		[task setArguments:args];
		inPipe = [[NSPipe alloc] init];
		readHandle = [inPipe fileHandleForReading];
		[task setStandardOutput: inPipe];
		[task launch];
		NSString* defaultsList = [[NSString alloc] initWithData:[readHandle readDataToEndOfFile]
													   encoding: NSUTF8StringEncoding];
		close([readHandle fileDescriptor]);
		[task waitUntilExit];
		status = [task terminationStatus];
		if(defaultsList) {
			[log appendFormat: @"Current user defaults:\n\n%@\n", defaultsList];
		}
		seteuid(0);

		NSFileManager* fileManager = [NSFileManager defaultManager];

		// print lockfile
		if([fileManager fileExistsAtPath: @"/etc/SelfControl.lock"]) {
			[log appendString: [NSString stringWithFormat: @"Found lock file with contents:\n\n%@\n\n", [NSString stringWithContentsOfFile: @"/etc/SelfControl.lock" encoding: NSUTF8StringEncoding error: NULL]]];
		} else {
			[log appendString: @"Could not find lock file.\n\n"];
		}

		// print pf.conf
		NSString* mainConf = [NSString stringWithContentsOfFile: @"/etc/pf.conf" encoding: NSUTF8StringEncoding error: nil];
		if([mainConf length]) {
			[log appendFormat: @"pf.conf file contents:\n\n%@\n", mainConf];
		} else {
			[log appendString: @"Could not find pf.conf file.\n"];
		}

		// print org.eyebeam pf anchors
		if([fileManager fileExistsAtPath: @"/etc/pf.anchors/org.eyebeam"]) {
			[log appendString: [NSString stringWithFormat: @"Found anchor file with contents:\n\n%@\n\n", [NSString stringWithContentsOfFile: @"/etc/pf.anchors/org.eyebeam" encoding: NSUTF8StringEncoding error: nil]]];
		}

		// print /etc/hosts contents
		[log appendFormat: @"Current /etc/hosts contents:\n\n%@\n\n", [NSString stringWithContentsOfFile: @"/etc/hosts" encoding: NSUTF8StringEncoding error: nil]];

		/* SECOND TASK: clear the block */

		task = [NSTask launchedTaskWithLaunchPath: @"/bin/launchctl"
										arguments: @[@"unload",
													 @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"]];
		[task waitUntilExit];
		
		status = [task terminationStatus];
		[log appendFormat: @"Unloading the launchd daemon returned: %d\n\n", status];

		BlockManager* bm = [[BlockManager alloc] init];
		BOOL cleared = [bm forceClearBlock];
		if (cleared) {
			[log appendString: @"SUCCESSFULLY CLEARED BLOCK!!! Used [BlockManager forceClearBlock]\n"];
		} else {
			[log appendString: @"FAILED TO CLEAR BLOCK! Used [BlockManager forceClearBlock]\n"];
		}

		// clear BlockStartedDate (legacy date value) from defaults
		seteuid(controllingUID);
		task = [NSTask launchedTaskWithLaunchPath: @"/usr/bin/defaults"
										arguments: @[@"delete",
													 @"org.eyebeam.SelfControl",
													 @"BlockStartedDate"]];
		[task waitUntilExit];
		status = [task terminationStatus];
		[log appendFormat: @"Deleting BlockStartedDate from defaults returned: %d\n", status];
		seteuid(0);
        
        // clear BlockEndDate (new date value) from defaults
        seteuid(controllingUID);
        task = [NSTask launchedTaskWithLaunchPath: @"/usr/bin/defaults"
                                        arguments: @[@"delete",
                                                     @"org.eyebeam.SelfControl",
                                                     @"BlockEndDate"]];
        [task waitUntilExit];
        status = [task terminationStatus];
        [log appendFormat: @"Deleting BlockEndDate from defaults returned: %d\n", status];
        seteuid(0);


		// remove PF token
		if([fileManager removeItemAtPath: @"/etc/SelfControlPFToken" error: nil]) {
			[log appendString: @"\nRemoved PF token file successfully.\n"];
		} else {
			[log appendString: @"\nFailed to remove PF token file.\n"];
		}

		// remove SC pf anchors
		if([fileManager fileExistsAtPath: @"/etc/pf.anchors/org.eyebeam"]) {
			if([fileManager removeItemAtPath: @"/etc/pf.anchors/org.eyebeam" error: nil])
				[log appendString: @"\nRemoved anchor file successfully.\n"];
			else
				[log appendString: @"\nFailed to remove anchor file.\n"];
		}

		// remove lockfile
		if([fileManager fileExistsAtPath: @"/etc/SelfControl.lock"]) {
			if([fileManager removeItemAtPath: @"/etc/SelfControl.lock" error: nil])
				[log appendString: @"\nRemoved lock file successfully.\n"];
			else
				[log appendString: @"\nFailed to remove lock file.\n"];
		}

		/* FINAL TASK: print any crashlogs we've got */

		if([fileManager fileExistsAtPath: @"/Library/Logs/CrashReporter"]) {
			NSArray* fileNames = [fileManager contentsOfDirectoryAtPath: @"/Library/Logs/CrashReporter" error: nil];
			for(int i = 0; i < [fileNames count]; i++) {
				NSString* fileName = fileNames[i];
				if([fileName rangeOfString: @"SelfControl"].location != NSNotFound) {
					[log appendFormat: @"Found crash log named %@ with contents:\n\n%@\n", fileName, [NSString stringWithContentsOfFile: [@"/Library/Logs/CrashReporter" stringByAppendingPathComponent: fileName] encoding: NSUTF8StringEncoding error: NULL]];
				}
			}
		}
		if([fileManager fileExistsAtPath: [@"~/Library/Logs/CrashReporter" stringByExpandingTildeInPath]]) {
			NSArray* fileNames = [fileManager contentsOfDirectoryAtPath: [@"~/Library/Logs/CrashReporter" stringByExpandingTildeInPath] error: nil];
			for(int i = 0; i < [fileNames count]; i++) {
				NSString* fileName = fileNames[i];
				if([fileName rangeOfString: @"SelfControl"].location != NSNotFound) {
					[log appendString: [NSString stringWithFormat: @"Found crash log named %@ with contents:\n\n%@\n", fileName, [NSString stringWithContentsOfFile: [[@"~/Library/Logs/CrashReporter" stringByExpandingTildeInPath] stringByAppendingPathComponent: fileName] encoding: NSUTF8StringEncoding error: NULL]]];
				}
			}
		}

		[log appendString: @"\n===SelfControl-Killer complete!==="];

		[log writeToFile: logFilePath
			  atomically: YES
				encoding: NSUTF8StringEncoding
				   error: nil];
	}
}
