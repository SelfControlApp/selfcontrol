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
#import "SCSettings.h"
#import "SCHelperToolUtilities.h"
#import "SCMiscUtilities.h"
#import <ServiceManagement/ServiceManagement.h>
#import "SCMigrationUtilities.h"
#import <sysexits.h>
#import "SCSentry.h"

#define LOG_FILE @"~/Documents/SelfControl-Killer.log"

int main(int argc, char* argv[]) {
	@autoreleasepool {
        [SCSentry startSentry: @"com.selfcontrolapp.SCKillerHelper"];
        
        // make sure to expand the tilde before we setuid to 0, otherwise this won't work
        NSString* logFilePath = [LOG_FILE stringByExpandingTildeInPath];
        NSMutableString* log = [NSMutableString stringWithString: @"===SelfControl-Killer Log File===\n\n"];

		if(geteuid()) {
			NSLog(@"ERROR: Helper tool must be run as root.");
            [SCSentry captureError: [SCErr errorWithCode: 402]];
			exit(EXIT_FAILURE);
		}

		if(argv[1] == NULL || argv[2] == NULL) {
			NSLog(@"ERROR: Not enough arguments");
			exit(EXIT_FAILURE);
		}
        
        NSString* killerKey = @(argv[1]);
        NSDate* keyDate = [[NSISO8601DateFormatter new] dateFromString: @(argv[2])];
        NSTimeInterval keyDateToNow = [[NSDate date] timeIntervalSinceDate: keyDate];
    
        // key date must exist, not be in the future, and be in the past 10 seconds
        if (keyDate == nil || keyDateToNow < 0 || keyDateToNow > 10) {
            NSLog(@"ERROR: Key date invalid");
            [SCSentry captureError: [SCErr errorWithCode: 404]];
            exit(EX_USAGE);
        }
        
        // keys must match
        NSString* correctKey = [SCMiscUtilities killerKeyForDate: keyDate];
        if (![correctKey isEqualToString: killerKey]) {
            NSLog(@"ERROR: Incorrect key");
            [SCSentry captureError: [SCErr errorWithCode: 403]];
            exit(EX_USAGE);
        }

		uid_t controllingUID = (uid_t)[@(argv[3]) intValue];
        if (controllingUID <= 0) {
            controllingUID = getuid();
        }

        // we need to setuid to root, otherwise launchctl won't find system launch daemons
        // depite the EUID being 0 as expected - not sure why that is
        setuid(0);

		/* FIRST TASK: print debug info */

		// print SC version:
		NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
		NSString* version = [infoDict objectForKey:@"CFBundleShortVersionString"];
        NSString* buildNumber = [infoDict objectForKey: @"CFBundleVersion"];
		[log appendFormat: @"SelfControl Version: %@ (%@)\n", version, buildNumber];

		// print system version
		[log appendFormat: @"System Version: Mac OS X %@\n\n", [[NSProcessInfo processInfo] operatingSystemVersionString]];

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
			[log appendFormat: @"Current user (%u) defaults:\n\n%@\n", getuid(), defaultsList];
		}
		seteuid(0);

        // and print new secured settings, if they exist
        SCSettings* settings = [SCSettings sharedSettings];
        [log appendFormat: @"Current secured settings:\n\n:%@\n", settings.dictionaryRepresentation];
        
        NSString* legacySettingsPath = [SCMigrationUtilities legacySecuredSettingsFilePathForUser: controllingUID];
        NSDictionary* legacySettingsDict = [NSDictionary dictionaryWithContentsOfFile: legacySettingsPath];
        if (legacySettingsDict) {
            [log appendFormat: @"Legacy (3.0-3.0.3) secured settings:\n\n:%@\n", legacySettingsDict];
        } else {
            [log appendFormat: @"Couldn't find legacy settings (from v3.0-3.0.3).\n\n"];
        }

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
			[log appendString: @"Could not find pf.conf file.\n\n"];
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
                                                     @"-w",
													 @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"]];
		[task waitUntilExit];
        status = [task terminationStatus];
		[log appendFormat: @"Unloading the legacy (1.0 - 3.0.3) launchd daemon returned: %d\n\n", status];
        
        CFErrorRef cfError;
        SILENCE_OSX10_10_DEPRECATION(
        SMJobRemove(kSMDomainSystemLaunchd, CFSTR("org.eyebeam.selfcontrold"), NULL, YES, &cfError);
                                     );
        if (cfError) {
            [log appendFormat: @"Failed to remove selfcontrold daemon (4.x) with error %@\n\n", cfError];
        } else {
            [log appendFormat: @"Successfully removed selfcontrold daemon (4.x)!\n\n"];
        }

		BlockManager* bm = [[BlockManager alloc] init];
		BOOL cleared = [bm forceClearBlock];
		if (cleared) {
			[log appendString: @"SUCCESSFULLY CLEARED BLOCK!!! Used [BlockManager forceClearBlock]\n"];
		} else {
			[log appendString: @"FAILED TO CLEAR BLOCK! Used [BlockManager forceClearBlock]\n"];
		}

		// clear BlockStartedDate (legacy date value) from defaults in case they're on an old version that still uses it
		seteuid(controllingUID);
		task = [NSTask launchedTaskWithLaunchPath: @"/usr/bin/defaults"
										arguments: @[@"delete",
													 @"org.eyebeam.SelfControl",
													 @"BlockStartedDate"]];
		[task waitUntilExit];
		status = [task terminationStatus];
		[log appendFormat: @"Deleting BlockStartedDate from defaults returned: %d\n", status];
		seteuid(0);
        
        // clear all modern secured settings (the user's copies of each setting will still be stored in defaults)
        [settings resetAllSettingsToDefaults];
        [settings synchronizeSettings];
        [log appendFormat: @"Reset all modern secured settings to default values.\n"];
        
        if ([SCMigrationUtilities legacySettingsFoundForUser: controllingUID]) {
            [SCMigrationUtilities copyLegacySettingsToDefaults: controllingUID];
            [SCMigrationUtilities clearLegacySettingsForUser: controllingUID ignoreRunningBlock: YES];
            [log appendFormat: @"Found, copied, and cleared legacy settings (v3.0-3.0.3)!\n"];
        } else {
            [log appendFormat: @"No legacy settings (v3.0-3.0.3) found.\n"];
        }

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
			for(NSUInteger i = 0; i < [fileNames count]; i++) {
				NSString* fileName = fileNames[i];
				if([fileName rangeOfString: @"SelfControl"].location != NSNotFound) {
					[log appendFormat: @"Found crash log named %@ with contents:\n\n%@\n", fileName, [NSString stringWithContentsOfFile: [@"/Library/Logs/CrashReporter" stringByAppendingPathComponent: fileName] encoding: NSUTF8StringEncoding error: NULL]];
				}
			}
		}
		if([fileManager fileExistsAtPath: [@"~/Library/Logs/CrashReporter" stringByExpandingTildeInPath]]) {
			NSArray* fileNames = [fileManager contentsOfDirectoryAtPath: [@"~/Library/Logs/CrashReporter" stringByExpandingTildeInPath] error: nil];
			for(NSUInteger i = 0; i < [fileNames count]; i++) {
				NSString* fileName = fileNames[i];
				if([fileName rangeOfString: @"SelfControl"].location != NSNotFound) {
					[log appendString: [NSString stringWithFormat: @"Found crash log named %@ with contents:\n\n%@\n", fileName, [NSString stringWithContentsOfFile: [[@"~/Library/Logs/CrashReporter" stringByExpandingTildeInPath] stringByAppendingPathComponent: fileName] encoding: NSUTF8StringEncoding error: NULL]]];
				}
			}
		}
                
        // OK, make sure all settings are synced before this thing exits
        NSError* syncSettingsErr = [settings syncSettingsAndWait: 5];
        
        if (syncSettingsErr != nil) {
            [log appendFormat: @"\nWARNING: Settings failed to synchronize before exit, with error %@", syncSettingsErr];
        }

       [log appendString: @"\n===SelfControl-Killer complete!==="];

       [log writeToFile: logFilePath
             atomically: YES
               encoding: NSUTF8StringEncoding
                  error: nil];

            
        // let the main app know to refresh
       [SCHelperToolUtilities sendConfigurationChangedNotification];

        exit(EX_OK);
	}
}
