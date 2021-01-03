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

int main(int argc, char* argv[]) {
	@autoreleasepool {

		if(geteuid()) {
			NSLog(@"ERROR: SelfControl's helper tool must be run as root.");
			printStatus(-201);
			exit(EX_NOPERM);
		}

		setuid(0);

		if(argc < 3 || argv[1] == NULL || argv[2] == NULL) {
			NSLog(@"ERROR: Not enough arguments");
			printStatus(-202);
			exit(EX_USAGE);
		}

		NSString* modeString = @(argv[2]);
		// We'll need the controlling UID to know what settings to read
		uid_t controllingUID = [@(argv[1]) intValue];

		// For proper security, we need to make sure that SelfControl files are owned
		// by root and only writable by root.  We'll define this here so we can use it
		// throughout the main function.
		NSDictionary* fileAttributes = @{NSFileOwnerAccountID: @0UL,
										 NSFileGroupOwnerAccountID: @0UL,
										 // 493 (decimal) = 755 (octal) = rwxr-xr-x
										 NSFilePosixPermissions: @493UL};


        SCSettings* settings = [SCSettings settingsForUser: controllingUID];

		if([modeString isEqual: @"--install"]) {
            if (blockIsRunningInSettingsOrDefaults(controllingUID)) {
                NSLog(@"ERROR: Block is already running");
                printStatus(-222);
                exit(EX_CONFIG);
            }

			NSFileManager* fileManager = [NSFileManager defaultManager];

			// Initialize writeErr to nil so calling messages on it later don't cause
			// crashes (it doesn't make sense we need to do this, but whatever).
			NSError* writeErr = nil;
			NSString* plistFormatPath = [[NSBundle mainBundle] pathForResource:@"org.eyebeam.SelfControl"
																		ofType:@"plist"];
			NSString* plistFormatString = [NSString stringWithContentsOfFile: plistFormatPath  encoding: NSUTF8StringEncoding error: NULL];
            
            // while the main app will just expect us to fetch the blocklist / end date from settings
            // this helper tool can also be used via command line with no other settings
            // (ex: by auto-selfcontrol) and in that case they'll pass a blocklist file and the end date via args
            // we should read those values into settings for use later
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
                    [settings setValue: blockEndDateArg forKey: @"BlockEndDate"];
                    NSDictionary* readProperties = [SCUtilities readBlocklistFromFile: [NSURL fileURLWithPath: pathToBlocklistFile]];
                    
                    if (readProperties == nil) {
                        NSLog(@"ERROR: Block could not be read from file %@", pathToBlocklistFile);
                        printStatus(-221);
                        syncSettingsAndExit(settings, EX_IOERR);
                    }
                    
                    [settings setValue: readProperties[@"Blocklist"] forKey: @"ActiveBlocklist"];
                    [settings setValue: readProperties[@"BlockAsWhitelist"] forKey: @"ActiveBlockAsWhitelist"];
                }
            }

			// get the expiration minute, to make sure we run the helper then (if it hasn't run already)
            // use the block end date from the argument if it's available; otherwise fall back to the one in settings
            NSDate* blockEndDate = (blockEndDateArg != nil) ? blockEndDateArg : [settings valueForKey: @"BlockEndDate"];
			NSCalendar* calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
			NSDateComponents* components = [calendar components: NSMinuteCalendarUnit fromDate: blockEndDate];
			long expirationMinute = [components minute];

			NSString* plistString = [NSString stringWithFormat:
									 plistFormatString,
									 MAX(expirationMinute - 1, 0),
									 expirationMinute,
									 MIN(expirationMinute + 1, 59),
									 controllingUID];
			[plistString writeToFile: @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"
						  atomically: YES
							encoding: NSUTF8StringEncoding
							   error: &writeErr];

			if([writeErr code]) {
				NSLog(@"ERROR: Could not write launchd plist file to LaunchDaemons folder.");
				printStatus(-204);
				syncSettingsAndExit(settings, EX_IOERR);
			}

			if(![fileManager fileExistsAtPath: @"/Library/PrivilegedHelperTools"]) {
				if(![fileManager createDirectoryAtPath: @"/Library/PrivilegedHelperTools"
						   withIntermediateDirectories: NO
											attributes: fileAttributes
												 error: nil]) {
					NSLog(@"ERROR: Could not create PrivilegedHelperTools directory.");
					printStatus(-205);
					syncSettingsAndExit(settings, EX_IOERR);
				}
			} else {
				if(![fileManager setAttributes: fileAttributes ofItemAtPath: @"/Library/PrivilegedHelperTools" error: nil]) {
					NSLog(@"ERROR: Could not change permissions on PrivilegedHelperTools directory.");
					printStatus(-206);
					syncSettingsAndExit(settings, EX_IOERR);
				}
			}
			// We should delete the old file if it exists and copy the new binary in,
			// because it might be a new version of the helper if we've upgraded SelfControl
			if([fileManager fileExistsAtPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl"]) {
				if(![fileManager removeItemAtPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl" error: nil]) {
					NSLog(@"ERROR: Could not delete old helper binary.");
					printStatus(-207);
					syncSettingsAndExit(settings, EX_IOERR);
				}
			}

			if(![fileManager copyItemAtPath: @(argv[0])
							   toPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl"
							  error: nil]) {
				NSLog(@"ERROR: Could not copy SelfControl's helper binary to PrivilegedHelperTools directory.");
				printStatus(-208);
				syncSettingsAndExit(settings, EX_IOERR);
			}

			if(![fileManager setAttributes: fileAttributes ofItemAtPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl" error: nil]) {
				NSLog(@"ERROR: Could not change permissions on SelfControl's helper binary.");
				printStatus(-209);
				syncSettingsAndExit(settings, EX_IOERR);
			}
            
            // clear any legacy block information - no longer useful since we're using SCSettings now
            // (and could potentially confuse things)
            [settings clearLegacySettings];
            
			if([[settings valueForKey: @"ActiveBlocklist"] count] <= 0 || ![SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]) {
				NSLog(@"ERROR: Blocklist is empty, or there was an error transferring block information.");
                NSLog(@"Block End Date: %@", [settings valueForKey: @"BlockEndDate"]);
				printStatus(-210);
				syncSettingsAndExit(settings, EX_CONFIG);
			}

			addRulesToFirewall(controllingUID);
            [settings setValue: @YES forKey: @"BlockIsRunning"];
            [settings synchronizeSettings]; // synchronize ASAP since BlockIsRunning is a really important one

            // first unload any old running copies, because otherwise we could end up with an old
            // version of the SC plist running with a newer version of the app
            // (calling load doesn't update the existing job if it's already running)
            [LaunchctlHelper unloadLaunchdJobWithPlistAt:@"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
			int result = [LaunchctlHelper loadLaunchdJobWithPlistAt: @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
            
            sendConfigurationChangedNotification();

			// Clear all caches if the user has the correct preference set, so
			// that blocked pages are not loaded from a cache.
			clearCachesIfRequested(controllingUID);

			if(result) {
				printStatus(-211);
                NSLog(@"WARNING: Launch daemon load returned a failure status code.");
				syncSettingsAndExit(settings, EX_UNAVAILABLE);
			} else NSLog(@"INFO: Block successfully added.");
		}
		if([modeString isEqual: @"--remove"]) {
			// So you think you can rid yourself of SelfControl just like that?
			NSLog(@"INFO: Nice try.");
			printStatus(-212);
			syncSettingsAndExit(settings, EX_UNAVAILABLE);
		} else if([modeString isEqual: @"--refresh"]) {
            // used when the blocklist may have changed, to make sure we are blocking the new list

            if([[settings valueForKey: @"ActiveBlocklist"] count] <= 0 || ![SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]) {
                NSLog(@"ERROR: Refreshing domain blocklist, but no block is currently ongoing or the blocklist is empty.");
                printStatus(-213);
                syncSettingsAndExit(settings, EX_SOFTWARE);
			}

			// Add and remove the rules to put in any new ones
			removeRulesFromFirewall(controllingUID);
			addRulesToFirewall(controllingUID);
            
            // make sure BlockIsRunning is still set
            [settings setValue: @YES forKey: @"BlockIsRunning"];
            [settings synchronizeSettings];
            
            // let the main app know things have changed so it can update the UI!
            sendConfigurationChangedNotification();

            // make sure the launchd job is still loaded
            [LaunchctlHelper loadLaunchdJobWithPlistAt: @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];

			// Clear web browser caches if the user has the correct preference set.  We
			// need to do this again even if it's only a refresh because there might be
			// caches for the new host blocked.
			clearCachesIfRequested(controllingUID);
        } else if([modeString isEqual: @"--checkup"]) {
            if(![SCUtilities blockIsRunningInDictionary: settings.dictionaryRepresentation]) {
                // No block appears to be running at all in our settings.
                // Most likely, the user removed it trying to get around the block. Boo!
                // but for safety and to avoid permablocks (we no longer know when the block should end)
                // we should clear the block now.
                // but let them know that we noticed their (likely) cheating and we're not happy!
                NSLog(@"ERROR: Checkup ran but no block found. Likely tampering! Removing block for safety, but flagging tampering.");

                // get rid of this block
                // Temporarily disabled the TamperingDetection flag because it was sometimes causing false positives
                // (i.e. people having the background set repeatedly despite no attempts to cheat)
                // We will try to bring this feature back once we can debug it
                // GitHub issue: https://github.com/SelfControlApp/selfcontrol/issues/621
                // [settings setValue: @YES forKey: @"TamperingDetected"];
                [settings synchronizeSettings];

                removeBlock(controllingUID);

                printStatus(-215);
                syncSettingsAndExit(settings, EX_SOFTWARE);
            }

			if (![SCUtilities blockShouldBeRunningInDictionary: settings.dictionaryRepresentation]) {
				NSLog(@"INFO: Checkup ran, block expired, removing block.");
                
				removeBlock(controllingUID);

				// Execution should never reach this point.  Launchd unloading the job in removeBlock()
				// should have killed this process.
				printStatus(-216);
				syncSettingsAndExit(settings, EX_SOFTWARE);
			} else {
				// The block is still on.  Check if anybody removed our rules, and if so
				// re-add them.  Also make sure the user's settings are set to the correct
				// settings just in case.
				PacketFilter* pf = [[PacketFilter alloc] init];
				HostFileBlocker* hostFileBlocker = [[HostFileBlocker alloc] init];
                if(![pf containsSelfControlBlock] || (![settings boolForKey: @"ActiveBlockAsWhitelist"] && ![hostFileBlocker containsSelfControlBlock])) {
					// The firewall is missing at least the block header.  Let's clear everything
					// before we re-add to make sure everything goes smoothly.

					[pf stopBlock: false];
					[hostFileBlocker writeNewFileContents];
					BOOL success = [hostFileBlocker writeNewFileContents];
					// Revert the host file blocker's file contents to disk so we can check
					// whether or not it still contains the block (aka we messed up).
					[hostFileBlocker revertFileContentsToDisk];
					if(!success || [hostFileBlocker containsSelfControlBlock]) {
						NSLog(@"WARNING: Error removing host file block.  Attempting to restore backup.");

						if([hostFileBlocker restoreBackupHostsFile])
							NSLog(@"INFO: Host file backup restored.");
						else
							NSLog(@"ERROR: Host file backup could not be restored.  This may result in a permanent block.");
					}

					// Get rid of the backup file since we're about to make a new one.
					[hostFileBlocker deleteBackupHostsFile];

					// Perform the re-add of the rules
					addRulesToFirewall(controllingUID);
                    
                    clearCachesIfRequested(controllingUID);
					NSLog(@"INFO: Checkup ran, readded block rules.");
				} else NSLog(@"INFO: Checkup ran, no action needed.");
			}
        } else if ([modeString isEqualToString: @"--print-settings"]) {
            NSLog(@" - Printing SelfControl secured settings for debug: - ");
            NSLog(@"%@", [settings dictionaryRepresentation]);
        } else if ([modeString isEqualToString: @"--is-running"]) {
            // pull up the user's defaults to check for the existence of a legacy block
            // to do that, we have to seteuid to the controlling UID so NSUserDefaults thinks we're them
            seteuid(controllingUID);
            NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
            [defaults addSuiteNamed: @"org.eyebeam.SelfControl"];
            [defaults synchronize];
            
            BOOL blockIsRunning = [SCUtilities blockIsRunningWithSettings: settings defaults: defaults];
            NSLog(@"%@", blockIsRunning ? @"YES" : @"NO");
            
            // reset the euid so nothing else gets funky
            [NSUserDefaults resetStandardUserDefaults];
            seteuid(0);
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
