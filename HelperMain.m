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
#import "SCBlockDateUtilities.h"
#import "SCSettings.h"

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
			NSFileManager* fileManager = [NSFileManager defaultManager];

			// Initialize writeErr to nil so calling messages on it later don't cause
			// crashes (it doesn't make sense we need to do this, but whatever).
			NSError* writeErr = nil;
			NSString* plistFormatPath = [[NSBundle mainBundle] pathForResource:@"org.eyebeam.SelfControl"
																		ofType:@"plist"];

			NSString* plistFormatString = [NSString stringWithContentsOfFile: plistFormatPath  encoding: NSUTF8StringEncoding error: NULL];

			// get the expiration minute, to make sure we run the helper then (if it hasn't run already)
            NSDate* blockEndDate = [settings valueForKey: @"BlockEndDate"];
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
				exit(EX_IOERR);
			}

			if(![fileManager fileExistsAtPath: @"/Library/PrivilegedHelperTools"]) {
				if(![fileManager createDirectoryAtPath: @"/Library/PrivilegedHelperTools"
						   withIntermediateDirectories: NO
											attributes: fileAttributes
												 error: nil]) {
					NSLog(@"ERROR: Could not create PrivilegedHelperTools directory.");
					printStatus(-205);
					exit(EX_IOERR);
				}
			} else {
				if(![fileManager setAttributes: fileAttributes ofItemAtPath: @"/Library/PrivilegedHelperTools" error: nil]) {
					NSLog(@"ERROR: Could not change permissions on PrivilegedHelperTools directory.");
					printStatus(-206);
					exit(EX_IOERR);
				}
			}
			// We should delete the old file if it exists and copy the new binary in,
			// because it might be a new version of the helper if we've upgraded SelfControl
			if([fileManager fileExistsAtPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl"]) {
				if(![fileManager removeItemAtPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl" error: nil]) {
					NSLog(@"ERROR: Could not delete old helper binary.");
					printStatus(-207);
					exit(EX_IOERR);
				}
			}

			if(![fileManager copyItemAtPath: @(argv[0])
							   toPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl"
							  error: nil]) {
				NSLog(@"ERROR: Could not copy SelfControl's helper binary to PrivilegedHelperTools directory.");
				printStatus(-208);
				exit(EX_IOERR);
			}

			if([fileManager fileExistsAtPath: @"/Library/PrivilegedHelperTools/scheckup"]) {
				if(![fileManager removeItemAtPath: @"/Library/PrivilegedHelperTools/scheckup" error: nil]) {
					NSLog(@"WARNING: Could not delete old scheckup binary.");
				}
			}
			NSString* scheckupPath = [@(argv[0]) stringByDeletingLastPathComponent];
			scheckupPath = [scheckupPath stringByAppendingPathComponent: @"scheckup"];

			if(![fileManager copyItemAtPath: scheckupPath
							   toPath: @"/Library/PrivilegedHelperTools/scheckup"
									  error: nil]) {
				NSLog(@"WARNING: Could not copy scheckup to PrivilegedHelperTools directory.");
			}

			// Let's set up our backup system -- give scheckup the SUID bit
			NSDictionary* checkupAttributes = @{NSFileOwnerAccountID: @0,
												NSFileGroupOwnerAccountID: @(controllingUID),
												// 2541 (decimal) = 4755 (octal) = rwsr-xr-x
												NSFilePosixPermissions: @2541UL};

			if(![fileManager setAttributes: checkupAttributes ofItemAtPath: @"/Library/PrivilegedHelperTools/scheckup" error: nil]) {
				NSLog(@"WARNING: Could not change file attributes on scheckup.  Backup block-removal system may not work.");
			}


			if(![fileManager setAttributes: fileAttributes ofItemAtPath: @"/Library/PrivilegedHelperTools/org.eyebeam.SelfControl" error: nil]) {
				NSLog(@"ERROR: Could not change permissions on SelfControl's helper binary.");
				printStatus(-209);
				exit(EX_IOERR);
			}

            // if we don't see the block enabled in settings, enable it, as the helper utility was probably started by command line and not through the AppController.
            // TODO: figure out when this happens, and fix it with the new settings
//            if(![SCBlockDateUtilities blockIsEnabledInDictionary: defaults]){
//                [SCBlockDateUtilities startDefaultsBlockWithDict: defaults forUID: controllingUID];
//            }

            SCSettings* settings = [SCSettings settingsForUser: controllingUID];
            
            // clear any legacy block information - no longer useful since we're using SCSettings now
            // (and could potentially confuse things)
            [settings clearLegacySettings];
            
			if([[settings valueForKey: @"Blocklist"] count] <= 0 || ![SCBlockDateUtilities blockIsEnabledInDictionary: settings.dictionaryRepresentation]) {
				NSLog(@"ERROR: Blocklist is empty, or there was an error transferring block information.");
				printStatus(-210);
				exit(EX_CONFIG);
			}

			addRulesToFirewall(controllingUID);
			int result = [LaunchctlHelper loadLaunchdJobWithPlistAt: @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];

			[[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification"
																		   object: nil];

			// Clear web browser caches if the user has the correct preference set, so
			// that blocked pages are not loaded from a cache.
			clearCachesIfRequested(controllingUID);

			if(result) {
				printStatus(-211);
                NSLog(@"WARNING: Launch daemon load returned a failure status code.");
				exit(EX_UNAVAILABLE);
			} else NSLog(@"INFO: Block successfully added.");
		}
		if([modeString isEqual: @"--remove"]) {
			// So you think you can rid yourself of SelfControl just like that?
			NSLog(@"INFO: Nice try.");
			printStatus(-212);
			exit(EX_UNAVAILABLE);
		} else if([modeString isEqual: @"--refresh"]) {
            // used when the blocklist may have changed, to make sure we are blocking the new list
            SCSettings* settings = [SCSettings settingsForUser: controllingUID];

            if([[settings valueForKey: @"Blocklist"] count] <= 0 || ![SCBlockDateUtilities blockIsEnabledInDictionary: settings.dictionaryRepresentation]) {
                NSLog(@"ERROR: Refreshing domain blacklist, but no block is currently ongoing or the blocklist is empty.");
                printStatus(-213);
                exit(EX_SOFTWARE);
			}

			// Add and remove the rules to put in any new ones
			removeRulesFromFirewall(controllingUID);
			addRulesToFirewall(controllingUID);

            // make sure the launchd job is still loaded
            [LaunchctlHelper loadLaunchdJobWithPlistAt: @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];

			// Clear web browser caches if the user has the correct preference set.  We
			// need to do this again even if it's only a refresh because there might be
			// caches for the new host blocked.
			clearCachesIfRequested(controllingUID);
        } else if([modeString isEqual: @"--checkup"]) {
            if(![SCBlockDateUtilities blockIsEnabledInDictionary: settings.dictionaryRepresentation]) {
                // No block is in settings at all, not even an inactive one. Weird!
                // we should try to remove any blocks just in case
                NSLog(@"ERROR: Checkup ran but no block found.  Attempting to remove block.");

                // get rid of this block
                removeBlock(controllingUID);

                printStatus(-215);
                exit(EX_SOFTWARE);
            }

			if (![SCBlockDateUtilities blockIsActiveInDictionary: settings.dictionaryRepresentation]) {
				NSLog(@"INFO: Checkup ran, block expired, removing block.");
                
				removeBlock(controllingUID);

				// Execution should never reach this point.  Launchd unloading the job in removeBlock()
				// should have killed this process.
				printStatus(-216);
				exit(EX_SOFTWARE);
			} else {
				// The block is still on.  Check if anybody removed our rules, and if so
				// re-add them.  Also make sure the user's settings are set to the correct
				// settings just in case.
				PacketFilter* pf = [[PacketFilter alloc] init];
				HostFileBlocker* hostFileBlocker = [[HostFileBlocker alloc] init];
                if(![pf containsSelfControlBlock] || (![settings valueForKey: @"BlockAsWhitelist"] && ![hostFileBlocker containsSelfControlBlock])) {
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
					NSLog(@"INFO: Checkup ran, readded block rules.");
				} else NSLog(@"INFO: Checkup ran, no action needed.");
			}
		}

		// by putting printStatus first (which tells the app we didn't crash), we fake it to
		// avoid memory-managment crashes (calling [pool drain] is essentially optional)
		printStatus(0);

	}
	exit(EXIT_SUCCESS);
}
