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
#import "SCBlockDateUtilities+HelperTools.h"

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
		// We'll need the controlling UID to know what defaults database to search
		uid_t controllingUID = [@(argv[1]) intValue];

		// For proper security, we need to make sure that SelfControl files are owned
		// by root and only writable by root.  We'll define this here so we can use it
		// throughout the main function.
		NSDictionary* fileAttributes = @{NSFileOwnerAccountID: @0UL,
										 NSFileGroupOwnerAccountID: @0UL,
										 // 493 (decimal) = 755 (octal) = rwxr-xr-x
										 NSFilePosixPermissions: @493UL};

		// This is where we get going with the lockfile system, saving a "lock" in /etc/SelfControl.lock
		// to make a more reliable block detection system.  For most of the program,
		// the pattern exhibited here will be used: we attempt to use the lock file's
		// contents, and revert to the user's defaults if the lock file has unreasonable
		// contents.
		NSDictionary* curLockDict = [NSDictionary dictionaryWithContentsOfFile: SelfControlLockFilePath];
		if(!([curLockDict[@"HostBlacklist"] count] <= 0))
			domainList = curLockDict[@"HostBlacklist"];

		registerDefaults(controllingUID);
		NSDictionary* defaults = getDefaultsDict(controllingUID);
		if(!domainList) {
			domainList = defaults[@"HostBlacklist"];
			if([domainList count] <= 0) {
				NSLog(@"ERROR: Not enough block information.");
				printStatus(-203);
				exit(EX_CONFIG);
			}
		}

		if([modeString isEqual: @"--install"]) {
			NSFileManager* fileManager = [NSFileManager defaultManager];

			// Initialize writeErr to nil so calling messages on it later don't cause
			// crashes (it doesn't make sense we need to do this, but whatever).
			NSError* writeErr = nil;
			NSString* plistFormatPath = [[NSBundle mainBundle] pathForResource:@"org.eyebeam.SelfControl"
																		ofType:@"plist"];

			NSString* plistFormatString = [NSString stringWithContentsOfFile: plistFormatPath  encoding: NSUTF8StringEncoding error: NULL];

			// get the expiration minute, to make sure we run the helper then (if it hasn't run already)
			NSTimeInterval blockDuration = [defaults[@"BlockDuration"] intValue];
			NSDate* expirationDate = [[NSDate date] dateByAddingTimeInterval: (blockDuration *60)];
			NSCalendar* calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
			NSDateComponents* components = [calendar components: NSMinuteCalendarUnit fromDate: expirationDate];
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

            // if we don't see the block enabled in defaults, enable it, as the helper utility was probably started by command line and not through the AppController.
            if(![SCBlockDateUtilities blockIsEnabledInDictionary: defaults]){
                [SCBlockDateUtilities startDefaultsBlockWithDict: defaults forUID: controllingUID];
            }

			NSDictionary* defaults = getDefaultsDict(controllingUID);
			// In this case it doesn't make any sense to use an existing lock file (in
			// fact, one shouldn't exist), so we fail if the defaults system has unreasonable
			// settings.
			NSDictionary* lockDictionary = @{@"HostBlacklist": defaults[@"HostBlacklist"],
											 @"BlockEndDate": [SCBlockDateUtilities blockEndDateInDictionary: defaults],
											 @"BlockAsWhitelist": defaults[@"BlockAsWhitelist"]};
			if([lockDictionary[@"HostBlacklist"] count] <= 0 || ![SCBlockDateUtilities blockIsEnabledInDictionary: lockDictionary]) {
				NSLog(@"ERROR: Not enough block information.");
				printStatus(-210);
				exit(EX_CONFIG);
			}

			// If perchance another lock is in existence already (which would be weird)
			// we try to remove a block and continue as normal.  This should definitely not be
			// happening though.
			if([fileManager fileExistsAtPath: SelfControlLockFilePath]) {
				NSLog(@"ERROR: Lock already established.  Attempting to stop block.");

				removeBlock(controllingUID);

				printStatus(-219);
				exit(EX_CONFIG);
			}

			// And write out our lock...
			if(![lockDictionary writeToFile: SelfControlLockFilePath atomically: YES]) {
				NSLog(@"ERROR: Could not write lock file.");
				printStatus(-216);
				exit(EX_IOERR);
			}
			// Make sure the privileges are correct on our lock file
			[fileManager setAttributes: fileAttributes ofItemAtPath: SelfControlLockFilePath error: nil];

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
			// Check what the current block is (based on the lock file) because if possible
			// we want to keep most of its information.
			NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: SelfControlLockFilePath];
			NSDictionary* newLockDictionary;

			NSDictionary* defaults = getDefaultsDict(controllingUID);
			if(curDictionary == nil) {
				// If there is no block file we just use all information from defaults

				if(![SCBlockDateUtilities blockIsEnabledInDictionary: defaults]) {
					// But if the block is already over (which is going to happen if the user
					// starts authentication for the host add and then the block expires before
					// they authenticate), we shouldn't do anything at all.

					NSLog(@"ERROR: Refreshing domain blacklist, but no block is currently ongoing.");
					printStatus(-213);
					exit(EX_SOFTWARE);
				}

				NSLog(@"WARNING: Refreshing domain blacklist, but no block is currently ongoing.  Relaunching block.");
				newLockDictionary = @{@"HostBlacklist": defaults[@"HostBlacklist"],
									  @"BlockEndDate": [SCBlockDateUtilities blockEndDateInDictionary: defaults],
									  @"BlockAsWhitelist": defaults[@"BlockAsWhitelist"]};
				// And later on we'll be reloading the launchd daemon if curDictionary
				// was nil, just in case.  Watch for it.
			} else {
				// If there is an existing block file we can save most of it from the old file
				newLockDictionary = @{@"HostBlacklist": defaults[@"HostBlacklist"],
									  @"BlockEndDate": [SCBlockDateUtilities blockEndDateInDictionary: curDictionary],
									  @"BlockAsWhitelist": curDictionary[@"BlockAsWhitelist"]};
			}

			if([newLockDictionary[@"HostBlacklist"] count] <= 0 || ![SCBlockDateUtilities blockIsEnabledInDictionary: newLockDictionary]) {
				NSLog(@"ERROR: Not enough block information.");
				printStatus(-214);
				exit(EX_CONFIG);
			}

			if(![newLockDictionary writeToFile: SelfControlLockFilePath atomically: YES]) {
				NSLog(@"ERROR: Could not write lock file.");
				printStatus(-217);
				exit(EX_IOERR);
			}
			// Make sure the privileges are correct on our lock file
			[[NSFileManager defaultManager] setAttributes: fileAttributes ofItemAtPath: SelfControlLockFilePath error: nil];
			domainList = newLockDictionary[@"HostBlacklist"];

			// Add and remove the rules to put in any new ones
			removeRulesFromFirewall(controllingUID);
			addRulesToFirewall(controllingUID);

			if(curDictionary == nil) {
				// aka if there was no lock file, and it's possible we're reloading the block,
				// and we're sure the block is still on (that's checked earlier).
				[LaunchctlHelper loadLaunchdJobWithPlistAt: @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
			}

			// Clear web browser caches if the user has the correct preference set.  We
			// need to do this again even if it's only a refresh because there might be
			// caches for the new host blocked.
			clearCachesIfRequested(controllingUID);
        } else if([modeString isEqual: @"--rewrite-lock-file"]) {
            NSDictionary* newLockDictionary;
            NSDictionary* defaults = getDefaultsDict(controllingUID);

            if(![SCBlockDateUtilities blockIsEnabledInDictionary: defaults]) {
                // But if the block is already over (which is going to happen if the user
                // starts authentication for the extension and then the block expires before
                // they authenticate), we shouldn't do anything at all.
                
                NSLog(@"ERROR: Extending block timer, but no block is currently ongoing.");
                printStatus(-213);
                exit(EX_SOFTWARE);
            }

            newLockDictionary = @{@"HostBlacklist": defaults[@"HostBlacklist"],
                              @"BlockEndDate": [SCBlockDateUtilities blockEndDateInDictionary: defaults],
                              @"BlockAsWhitelist": defaults[@"BlockAsWhitelist"]};
            
            if([newLockDictionary[@"HostBlacklist"] count] <= 0 || ![SCBlockDateUtilities blockIsEnabledInDictionary: newLockDictionary]) {
                NSLog(@"ERROR: Not enough block information.");
                printStatus(-214);
                exit(EX_CONFIG);
            }
            
            if(![newLockDictionary writeToFile: SelfControlLockFilePath atomically: YES]) {
                NSLog(@"ERROR: Could not write lock file.");
                printStatus(-217);
                exit(EX_IOERR);
            }
            // Make sure the privileges are correct on our lock file
            [[NSFileManager defaultManager] setAttributes: fileAttributes ofItemAtPath: SelfControlLockFilePath error: nil];
            domainList = newLockDictionary[@"HostBlacklist"];
            
            // Reload the launchd job just in case
            [LaunchctlHelper loadLaunchdJobWithPlistAt: @"/Library/LaunchDaemons/org.eyebeam.SelfControl.plist"];
        } else if([modeString isEqual: @"--checkup"]) {
			NSDictionary* curDictionary = [NSDictionary dictionaryWithContentsOfFile: SelfControlLockFilePath];

			if(![SCBlockDateUtilities blockIsEnabledInDictionary: curDictionary]) {
				// The lock file seems to be broken (no block found).  Read from defaults to try to find the block.
                curDictionary = getDefaultsDict(controllingUID);
                
                // TODO: we should make sure we update the lock file after this too so we have a backup
                
				if(![SCBlockDateUtilities blockIsEnabledInDictionary: curDictionary]) {
					// Defaults is broken too!  Let's get out of here!
					NSLog(@"ERROR: Checkup ran but no block found.  Attempting to remove block.");

					// get rid of this block
					removeBlock(controllingUID);

					printStatus(-215);
					exit(EX_SOFTWARE);
				}
			}

			// Note there are a few extra possible conditions on this if statement, this
			// makes it more likely that an improperly applied block might come right
			// off.
			if (![SCBlockDateUtilities blockIsActiveInDictionary: curDictionary]) {
				NSLog(@"INFO: Checkup ran, block expired, removing block.");

				removeBlock(controllingUID);

				// Execution should never reach this point.  Launchd unloading the job in removeBlock()
				// should have killed this process.
				printStatus(-216);
				exit(EX_SOFTWARE);
			} else {
				// The block is still on.  Check if anybody removed our rules, and if so
				// re-add them.  Also make sure the user's defaults are set to the correct
				// settings just in case.
				PacketFilter* pf = [[PacketFilter alloc] init];
				HostFileBlocker* hostFileBlocker = [[HostFileBlocker alloc] init];
				if(![pf containsSelfControlBlock] || (!curDictionary[@"BlockAsWhitelist"] && ![hostFileBlocker containsSelfControlBlock])) {
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

				// Why would we make sure the defaults are correct even if we can get the
				// info from the lock file?  In case one goes down, we want to make sure
				// we always have a backup.
				setDefaultsValue(@"BlockEndDate", [SCBlockDateUtilities blockEndDateInDictionary: curDictionary], controllingUID);
				setDefaultsValue(@"HostBlacklist", domainList, controllingUID);
                setDefaultsValue(@"BlockAsWhitelist", curDictionary[@"BlockAsWhitelist"], controllingUID);
                
                // BlockStartedDate is a legacy value, no need for it now that we added a BlockEndDate
                setDefaultsValue(@"BlockStartedDate", nil, controllingUID);
			}
		}

		// by putting printStatus first (which tells the app we didn't crash), we fake it to
		// avoid memory-managment crashes (calling [pool drain] is essentially optional)
		printStatus(0);

	}
	exit(EXIT_SUCCESS);
}
