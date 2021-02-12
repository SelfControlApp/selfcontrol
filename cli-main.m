//
//  cli-main.m
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

#import "PacketFilter.h"
#import "SCHelperToolUtilities.h"
#import "SCSettings.h"
#import "SCXPCClient.h"
#import "SCBlockFileReaderWriter.h"
#import <sysexits.h>
#import "XPMArguments.h"

// The main method which deals which most of the logic flow and execution of
// the CLI tool.
int main(int argc, char* argv[]) {
    [SCSentry startSentry: @"org.eyebeam.selfcontrol-cli"];

    @autoreleasepool {
        XPMArgumentSignature
          * controllingUIDSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[--uid]="],
          * startSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[start --start --install]"],
          * blocklistSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[--blocklist -b]="],
          * blockEndDateSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[--enddate -d]="],
          * blockSettingsSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[--settings -s]="],
          * removeSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[remove --remove]"],
          * printSettingsSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[print-settings --printsettings -p]"],
          * isRunningSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[is-running --isrunning -r]"],
          * versionSig = [XPMArgumentSignature argumentSignatureWithFormat:@"[version --version -v]"];
        NSArray * signatures = @[controllingUIDSig, startSig, blocklistSig, blockEndDateSig, blockSettingsSig, removeSig, printSettingsSig, isRunningSig, versionSig];
        XPMArgumentPackage * arguments = [[NSProcessInfo processInfo] xpmargs_parseArgumentsWithSignatures:signatures];
        
        // We'll need the controlling UID to know what settings to read
        // try reading it from the command-line, otherwise if we're not root we use the current uid
        uid_t controllingUID = (uid_t)[[arguments firstObjectForSignature: controllingUIDSig] intValue];
        if (controllingUID <= 0) {
            // for legacy reasons, we'll also take an unlabeled argument that looks like an UID
            // (this makes us backwards-compatible with SC versions pre-4.0)
            for (NSString* uncapturedArg in arguments.uncapturedValues) {
                NSRange range = [uncapturedArg rangeOfString: @"^[0-9]{3}$" options: NSRegularExpressionSearch];
                if (range.location != NSNotFound) {
                    controllingUID = (uid_t)[uncapturedArg intValue];
                }
            }
        }
        if (controllingUID <= 0) {
            controllingUID = getuid();
        }

        SCSettings* settings = [SCSettings sharedSettings];
        
        NSDictionary* defaultsDict;
        // if we're running as root/sudo and we have a controlling UID, use defaults for the controlling user (legacy behavior)
        // otherwise, just use the current user's defaults (modern behavior)
        if (geteuid() == 0 && controllingUID > 0) {
            defaultsDict = [SCMiscUtilities defaultsDictForUser: controllingUID];
        } else {
            NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
            [defaults registerDefaults: SCConstants.defaultUserDefaults];
            defaultsDict = defaults.dictionaryRepresentation;
        }
        
		if([arguments booleanValueForSignature: startSig]) {
            [SCSentry addBreadcrumb: @"CLI method --install called" category: @"cli"];

            if ([SCBlockUtilities anyBlockIsRunning]) {
                NSLog(@"ERROR: Block is already running");
                exit(EX_CONFIG);
            }

            NSArray* blocklist;
            NSDate* blockEndDate;
            BOOL blockAsWhitelist = NO;
            NSDictionary* blockSettings;
            
            // there are two ways we can read in the core block parameters (Blocklist, BlockEndDate, BlockAsWhitelist):
            // 1) we can receive them as command-line arguments, including a path to a blocklist file
            // 2) we can read them from user defaults (for legacy support, don't encourage this)
            NSString* pathToBlocklistFile = [arguments firstObjectForSignature: blocklistSig];
            NSDate* blockEndDateArg = [[NSISO8601DateFormatter new] dateFromString: [arguments firstObjectForSignature: blockEndDateSig]];

            // if we didn't get a valid block end date in the future, try our next approach: legacy unlabeled arguments
            // this is for backwards compatibility. In SC pre-4.0, this used to be called as --install {uid} {pathToBlocklistFile} {blockEndDate}
            // we'll sidestep XPMArgumentParser here because the legacy stuff was dumber and just dealt with args by index
            if ((pathToBlocklistFile == nil || blockEndDateArg == nil || [blockEndDateArg timeIntervalSinceNow] < 1)
                && (argv[3] != NULL && argv[4] != NULL)) {
                
                pathToBlocklistFile = @(argv[3]);
                blockEndDateArg = [[NSISO8601DateFormatter new] dateFromString: @(argv[4])];
                NSLog(@"created legacy block end date %@ from %@", blockEndDateArg, @(argv[4]));
            }
            
            // if we got valid block arguments from the command-line, read in that file
            if (pathToBlocklistFile != nil && blockEndDateArg != nil && [blockEndDateArg timeIntervalSinceNow] >= 1) {
                NSLog(@"no path to blocklist file, and block end date is good");
                blockEndDate = blockEndDateArg;
                NSDictionary* readProperties = [SCBlockFileReaderWriter readBlocklistFromFile: [NSURL fileURLWithPath: pathToBlocklistFile]];
                
                if (readProperties == nil) {
                    NSLog(@"ERROR: Block could not be read from file %@", pathToBlocklistFile);
                    exit(EX_IOERR);
                }
                
                blocklist = readProperties[@"Blocklist"];
                blockAsWhitelist = [readProperties[@"BlockAsWhitelist"] boolValue];
                NSLog(@"READ BLOCKLIST %@ from %@", blocklist, pathToBlocklistFile);
            } else {
                NSLog(@"pulling from defaults because path is %@ and block end date arg is %@", pathToBlocklistFile, blockEndDateArg);
                // if the command-line had nothing from us, we'll try to pull them from defaults
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
                @"EnableErrorReporting": defaultsDict[@"EnableErrorReporting"]
            };

            if([blocklist count] == 0 || [blockEndDate timeIntervalSinceNow] < 1) {
                // ya can't start a block without a blocklist, and it can't run for less than a second
                // because that's silly
                NSLog(@"ERROR: Blocklist is empty, or block does not end in the future (%@, %@).", blocklist, blockEndDate);
                exit(EX_CONFIG);
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

            [xpc installDaemon:^(NSError * _Nonnull error) {
                if (error != nil) {
                    NSLog(@"ERROR: Failed to install daemon with error %@", error);
                    exit(EX_SOFTWARE);
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
                            if (error != nil) {
                                NSLog(@"ERROR: Daemon failed to start block with error %@", error);
                                exit(EX_SOFTWARE);
                                return;
                            }

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
		if([arguments booleanValueForSignature: removeSig]) {
            [SCSentry addBreadcrumb: @"CLI method --remove called" category: @"cli"];
			// So you think you can rid yourself of SelfControl just like that?
			NSLog(@"INFO: Nice try.");
            exit(EX_UNAVAILABLE);
        } else if ([arguments booleanValueForSignature: printSettingsSig]) {
            [SCSentry addBreadcrumb: @"CLI method --print-settings called" category: @"cli"];
            NSLog(@" - Printing SelfControl secured settings for debug: - ");
            NSLog(@"%@", [settings dictionaryRepresentation]);
        } else if ([arguments booleanValueForSignature: isRunningSig]) {
            [SCSentry addBreadcrumb: @"CLI method --is-running called" category: @"cli"];
            BOOL blockIsRunning = [SCBlockUtilities anyBlockIsRunning];
            NSLog(@"%@", blockIsRunning ? @"YES" : @"NO");
        } else if ([arguments booleanValueForSignature: versionSig]) {
            [SCSentry addBreadcrumb: @"CLI method --version called" category: @"cli"];
            NSLog(SELFCONTROL_VERSION_STRING);
        }

        // final sync before we exit
        exit(EXIT_SUCCESS);
	}
}
