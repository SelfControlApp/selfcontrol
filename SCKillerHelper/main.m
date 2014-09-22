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

		// print lockfile
		if([[NSFileManager defaultManager] fileExistsAtPath: @"/etc/SelfControl.lock"]) {
			[log appendString: [NSString stringWithFormat: @"Found lock file with contents:\n\n%@\n\n", [NSString stringWithContentsOfFile: @"/etc/SelfControl.lock" encoding: NSUTF8StringEncoding error: NULL]]];
		} else {
			[log appendString: @"Could not find lock file.\n"];
		}

		// print pf.conf
		NSString* mainConf = [NSString stringWithContentsOfFile: @"/etc/pf.conf" encoding: NSUTF8StringEncoding error: nil];
		if([mainConf length]) {
			[log appendFormat: @"pf.conf file contents:\n\n%@\n", mainConf];
		} else {
			[log appendString: @"Could not find pf.conf file.\n"];
		}

		// print org.eyebeam pf anchors
		if([[NSFileManager defaultManager] fileExistsAtPath: @"/etc/pf.anchors/org.eyebeam"]) {
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

		BlockManager* bm = [[BlockManager alloc] initAsWhitelist: NO];
		BOOL cleared = [bm forceClearBlock];
		if (cleared) {
			[log appendString: @"SUCCESSFULLY CLEARED BLOCK!!! Used [BlockManager forceClearBlock]\n"];
		} else {
			[log appendString: @"FAILED TO CLEAR BLOCK! Used [BlockManager forceClearBlock]\n"];
		}

		// clear defaults
		seteuid(controllingUID);
		task = [NSTask launchedTaskWithLaunchPath: @"/usr/bin/defaults"
										arguments: @[@"delete",
													 @"org.eyebeam.SelfControl"]];
		[task waitUntilExit];
		status = [task terminationStatus];
		[log appendFormat: @"Deleting the defaults returned: %d\n", status];
		seteuid(0);

		// remove PF token
		if([[NSFileManager defaultManager] removeFileAtPath: @"/etc/SelfControlPFToken" handler: nil]) {
			[log appendString: @"\nRemoved PF token file successfully.\n"];
		} else {
			[log appendString: @"\nFailed to remove PF token file.\n"];
		}

		// remove SC pf anchors
		if([[NSFileManager defaultManager] fileExistsAtPath: @"/etc/pf.anchors/org.eyebeam"]) {
			if([[NSFileManager defaultManager] removeFileAtPath: @"/etc/pf.anchors/org.eyebeam" handler: nil])
				[log appendString: @"\nRemoved anchor file successfully.\n"];
			else
				[log appendString: @"\nFailed to remove anchor file.\n"];
		}

		// remove lockfile
		if([[NSFileManager defaultManager] fileExistsAtPath: @"/etc/SelfControl.lock"]) {
			if([[NSFileManager defaultManager] removeFileAtPath: @"/etc/SelfControl.lock" handler: nil])
				[log appendString: @"\nRemoved lock file successfully.\n"];
			else
				[log appendString: @"\nFailed to remove lock file.\n"];
		}

		/* FINAL TASK: print any crashlogs we've got */

		if([[NSFileManager defaultManager] fileExistsAtPath: @"/Library/Logs/CrashReporter"]) {
			NSArray* fileNames = [[NSFileManager defaultManager] directoryContentsAtPath: @"/Library/Logs/CrashReporter"];
			for(int i = 0; i < [fileNames count]; i++) {
				NSString* fileName = fileNames[i];
				if([fileName rangeOfString: @"SelfControl"].location != NSNotFound) {
					[log appendFormat: @"Found crash log named %@ with contents:\n\n%@\n", fileName, [NSString stringWithContentsOfFile: [@"/Library/Logs/CrashReporter" stringByAppendingPathComponent: fileName] encoding: NSUTF8StringEncoding error: NULL]];
				}
			}
		}
		if([[NSFileManager defaultManager] fileExistsAtPath: [@"~/Library/Logs/CrashReporter" stringByExpandingTildeInPath]]) {
			NSArray* fileNames = [[NSFileManager defaultManager] directoryContentsAtPath: [@"~/Library/Logs/CrashReporter" stringByExpandingTildeInPath]];
			for(int i = 0; i < [fileNames count]; i++) {
				NSString* fileName = fileNames[i];
				if([fileName rangeOfString: @"SelfControl"].location != NSNotFound) {
					[log appendString: [NSString stringWithFormat: @"Found crash log named %@ with contents:\n\n%@\n", fileName, [NSString stringWithContentsOfFile: [[@"~/Library/Logs/CrashReporter" stringByExpandingTildeInPath] stringByAppendingPathComponent: fileName] encoding: NSUTF8StringEncoding error: NULL]]];
				}
			}
		}

		[log appendString: @"\n===SelfControl-Killer complete!==="];

		[log writeToFile: logFilePath atomically: YES];
	}
}
