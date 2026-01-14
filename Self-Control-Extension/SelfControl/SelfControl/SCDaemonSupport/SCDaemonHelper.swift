//
//  SCDaemonHelper.swift
//  SelfControl
//
//  Created by Satendra Singh on 22/12/25.
//

import Foundation

final class SSCDaemonHelper {
    let xpc = SCXPCClient()

    init() {
        
    }
    
    func install(blockedDomains: [String], time: Date) {
        xpc.installDaemon { (error: Error?) in
            if let error = error {
                NSLog("ERROR: Failed to install daemon with error \(error)")
                exit(EX_SOFTWARE)
            } else {
                //                NSTimeInterval blockDurationSecs = MAX([[self->defaults_ valueForKey: @"BlockDuration"] intValue] * 60, 0);
                //                NSDate* newBlockEndDate = [NSDate dateWithTimeIntervalSinceNow: blockDurationSecs];
//                let date = Date().addingTimeInterval(5*60) //add second
                let blockSettingsFromDefaults: [String: Any] = [
                    "ClearCaches": 1,
                    "AllowLocalNetworks": 1,
                    "EvaluateCommonSubdomains": 1,
                    "IncludeLinkedDomains": 1,
                    "BlockSoundShouldPlay": 0,
                    "BlockSound": 5,
                    "EnableErrorReporting": 1
                ]
                let blockSettings = blockSettingsFromDefaults
                // ok, the new helper tool is installed! refresh the connection, then it's time to start the block
                self.xpc.refreshConnectionAndRun {
                    NSLog("Refreshed connection and ready to start block!")
                    self.xpc.startBlock(
                        withControllingUID: getuid(),
                        blocklist: blockedDomains,
                        isAllowlist: false,
                        end: time,
                        blockSettings: blockSettings
                    ) { (error: Error?) in
                        if let error = error {
                            NSLog("ERROR: Daemon failed to start block with error \(error)")
                            exit(EX_SOFTWARE)
                        }

                        NSLog("INFO: Block successfully added.")
                        //                        installingBlockSema.signal()
                    }
                }
            }
        }
    }
    
    func connect() {
        xpc.connectToHelperTool()
    }
    
    func updateBlocklist(_ domains: [String])  {
        xpc.updateBlocklist(domains) { error in
            print("\(error.localizedDescription )")
        }
    }
}

