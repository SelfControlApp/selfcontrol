//
//  main.swift
//  SelfControlExtension
//
//  Created by Egzon Arifi on 02/04/2025.
//

import Foundation
import NetworkExtension
import os.log

autoreleasepool {
  os_log("[SC] 🔍] first light")
  NEProvider.startSystemExtensionMode()
  IPCConnection.shared.startListener()
}

dispatchMain()
