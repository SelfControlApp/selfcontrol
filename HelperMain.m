//
//  helpermain.m
//  SelfControl
//
//  Created by Charlie Stigler on 2/4/09.
//  Copyright 2009 Eyebeam.

// This file is part of SelfControl.
//
// SelfControl is free software:  you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "HelperMain.h"
#import "SCUtilities.h"
#import "SCSettings.h"
#import "version-header.h"
#import "SCConstants.h"
#import "SCXPCClient.h"

int main(int argc, char* argv[]) {
	@autoreleasepool {
		if(argc < 3 || argv[1] == NULL || argv[2] == NULL) {
			NSLog(@"ERROR: Not enough arguments");
			printStatus(-202);
			exit(EX_USAGE);
		}

		NSString* modeString = @(argv[2]);
		// We'll need the controlling UID to know what settings to read
		uid_t controllingUID = [@(argv[1]) intValue];

        SCSettings* settings = [SCSettings sharedSettings];
        
        NSDictionary* defaultsDict;
        // if we're running as root/sudo and we have a controlling UID, use defaults for the controlling user (legacy behavior)
        // otherwise, just use the current user's defaults (modern behavior)
        if (geteuid() == 0 && controllingUID > 0) {
            defaultsDict = [SCUtilities defaultsDictForUser: controllingUID];
        } else {
            defaultsDict = [NSUserDefaults standardUserDefaults].dictionaryRepresentation;
        }
        
		if([modeString isEqual: @"--install"]) {
            if (blockIsRunningInSettingsOrDefaults(controllingUID)) {
                NSLog(@"ERROR: Block is already running");
                printStatus(-222);
                exit(EX_CONFIG);
            }

            NSArray* blocklist;
            NSDate* blockEndDate;
            BOOL blockAsWhitelist = NO;
            NSDictionary* blockSettings;
            
            // there are two ways we can read in the core block parameters (Blocklist, BlockEndDate, BlockAsWhitelist):
            // 1) we can receive them as command-line arguments, including a path to a blocklist file
            // 2) we can read them from user defaults (for legacy support, don't encouarge this)
            NSString* pathToBlocklistFile;
            NSDate* blockEndDateArg;
            if (argv[3] != NULL && argv[4] != NULL) {
                pathToBlocklistFile = @(argv[3]);
                blockEndDateArg = [[NSISO8601DateFormatter new] dateFromString: @(argv[4])];
                                
                // if we didn't get a valid block end date in the future, ignore the other args
                if (blockEndDateArg == nil || [blockEndDateArg timeIntervalSinceNow] < 1) {
                    pathToBlocklistFile = nil;
                    NSLog(@"Error: Block end date argument %@ is invalid", @(argv[4]));
                    printStatus(-220);
                    syncSettingsAndExit(settings, EX_IOERR);
                } else {
                    blockEndDate = blockEndDateArg;
                    NSDictionary* readProperties = [SCUtilities readBlocklistFromFile: [NSURL fileURLWithPath: pathToBlocklistFile]];
                    
                    if (readProperties == nil) {
                        NSLog(@"ERROR: Block could not be read from file %@", pathToBlocklistFile);
                        printStatus(-221);
                        syncSettingsAndExit(settings, EX_IOERR);
                    }
                    
                    blocklist = readProperties[@"Blocklist"];
                    blockAsWhitelist = [readProperties[@"BlockAsWhitelist"] boolValue];
                }
            } else {
                blocklist = defaultsDict[@"Blocklist"];
                blockAsWhitelist = [defaultsDict[@"BlockAsWhitelist"] boolValue];
                
                NSTimeInterval blockDurationSecs = MAX([defaultsDict[@"BlockDuration"] intValue] * 60, 0);
                blockEndDate = [NSDate dateWithTimeIntervalSinceNow: blockDurationSecs];
            }
            
            // read in the other block settings, for now only accepted via defaults
            // TODO: accept these via arguments also
            blockSettings = @{
                @"ClearCaches": defaultsDict[@"ClearCaches"],
                @"AllowLocalNetworks": defaultsDict[@"AllowLocalNetworks"],
                @"EvaluateCommonSubdomains": defaultsDict[@"EvaluateCommonSubdomains"],
                @"IncludeLinkedDomains": defaultsDict[@"IncludeLinkedDomains"],
                @"BlockSoundShouldPlay": defaultsDict[@"BlockSoundShouldPlay"],
                @"BlockSound": defaultsDict[@"BlockSound"],
            };

            if([blocklist count] == 0 || [blockEndDate timeIntervalSinceNow] < 1) {
                // ya can't start a block without a blocklist, and it can't run for less than a second
                // because that's silly
                NSLog(@"ERROR: Blocklist is empty, or block does not end in the future.");
                printStatus(-210);
                syncSettingsAndExit(settings, EX_CONFIG);
            }

			// We should try to delete the old helper tool if it exists, to avoid confusion
            NSFileManager* fileManager = [NSFileManager defaultManager];
			if([fileManager fileExistsAtPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl"]) {
				if(![fileManager removeItemAtPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl" error: nil]) {
					NSLog(@"WARNING: Could not delete old helper binary.");
				}
			}
            
            SCXPCClient* xpc = [SCXPCClient new];

            // use a semaphore to make sure the command-line tool doesn't exit
            // while our blocks are still running
            dispatch_semaphore_t installingBlockSema = dispatch_semaphore_create(0);
            
            NSLog(@"About to install helper tool");
            [xpc installDaemon:^(NSError * _Nonnull error) {
                if (error != nil) {
                    NSLog(@"ERROR: Failed to install helper tool with error %@", error);
                    printStatus(-402);
                    syncSettingsAndExit(settings, EX_SOFTWARE);
                    return;
                } else {
                    // ok, the new helper tool is installed! refresh the connection, then it's time to start the block
                    [xpc refreshConnectionAndRun:^{
                        NSLog(@"Refreshed connection and ready to start block!");
                        [xpc startBlockWithControllingUID: controllingUID
                                                     blocklist: blocklist
                                                   isAllowlist: blockAsWhitelist
                                                       endDate: blockEndDate
                                                 blockSettings: blockSettings
                                                         reply:^(NSError * _Nonnull error) {
                            NSLog(@"WOO started block with error %@", error);
                            if (error != nil) {
                                NSLog(@"ERROR: Daemon failed to start block with error %@", error);
                                printStatus(-403);
                                syncSettingsAndExit(settings, EX_SOFTWARE);
                                return;
                            }
                            
                            // TODO: is this necessary?
                            sendConfigurationChangedNotification();
                            
                            NSLog(@"INFO: Block successfully added.");
                            dispatch_semaphore_signal(installingBlockSema);
                        }];
                    }];
                }
            }];
            
            // obj-c could decide to run our things on the main thread, or not, so be careful
            // but don't let us continue until the block has executed
            if (![NSThread isMainThread]) {
                dispatch_semaphore_wait(installingBlockSema, DISPATCH_TIME_FOREVER);
            } else {
                while (dispatch_semaphore_wait(installingBlockSema, DISPATCH_TIME_NOW)) {
                    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate: [NSDate date]];
                }
            }
        }
		if([modeString isEqual: @"--remove"]) {
			// So you think you can rid yourself of SelfControl just like that?
			NSLog(@"INFO: Nice try.");
			printStatus(-212);
			syncSettingsAndExit(settings, EX_UNAVAILABLE);
        } else if ([modeString isEqualToString: @"--print-settings"]) {
            NSLog(@" - Printing SelfControl secured settings for debug: - ");
            NSLog(@"%@", [settings dictionaryRepresentation]);
        } else if ([modeString isEqualToString: @"--is-running"]) {
            BOOL blockIsRunning = [SCUtilities blockIsRunningWithSettings: settings defaultsDict: defaultsDict];
            NSLog(@"%@", blockIsRunning ? @"YES" : @"NO");
        } else if ([modeString isEqualToString: @"--version"]) {
            NSLog(SELFCONTROL_VERSION_STRING);
        }

		// by putting printStatus first (which tells the app we didn't crash), we fake it to
		// avoid memory-managment crashes (calling [pool drain] is essentially optional)
		printStatus(0);

        // final sync before we exit
        syncSettingsAndExit(settings, EXIT_SUCCESS);
	}

    // wait, how'd we get out of the autorelease block without hitting the exit just above this?
    // whoops, something broke
	exit(EX_SOFTWARE);
}
