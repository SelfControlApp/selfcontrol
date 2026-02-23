//
//  SafariExtensionManager.swift
//  SelfControl
//
//  Created by Satendra Singh on 24/11/25.
//

import Foundation
import os.log

final class SafariExtensionManager: ObservableObject {
    static let shared = SafariExtensionManager()
    var onExtensionStateChange: (() -> Void)?
    private var isReady: Bool = false
    private var isEnabled = false
    var lastUpdateReceivedTime: Date? {
        didSet {
            onExtensionStateChange?()
        }
    }
    
    private init() {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults(suiteName: SafariConst.appGroup),
            queue: .main
        ) { notification in
            let shared = UserDefaults(suiteName: SafariConst.appGroup)
            print("Received from extension:", shared?.string(forKey: "ready") ?? "")
            if let value = shared?.bool(forKey: "ready") {
                if value == true {
                    print("Ready now:")
                    if self.isReady == false {
                        self.onExtensionStateChange?()
                        self.isReady = true
                    }
                }
            }
        }
        registerForUpdates()
    }
    
    var isExtensionReady: Bool {
        guard let lastUpdateReceivedTime = lastUpdateReceivedTime else { return false }
        // Consider the extension "ready" if we received an update within the last 35 seconds
        return Date().timeIntervalSince(lastUpdateReceivedTime) <= 35
//        return UserDefaults(suiteName: appGroup)?.bool(forKey: "ready") == true
    }
    
    func enableExtension() {
        let defaults = UserDefaults(suiteName: SafariConst.appGroup)
        defaults?.set(true, forKey: "enabled")
        defaults?.synchronize()
    }
    
    func disableExtension() {
        let defaults = UserDefaults(suiteName: SafariConst.appGroup)
        defaults?.set(false, forKey: "enabled")
        defaults?.synchronize()
    }
    
    func resetExtensionState() {
        let defaults = UserDefaults(suiteName: SafariConst.appGroup)
        defaults?.set(false, forKey: "enabled")
        defaults?.set(false, forKey: "ready")
        defaults?.synchronize()
    }
    
    func registerForUpdates() {
//        let path = (NSHomeDirectory() + "/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari.Extensions.plist")
//
//        let fileDescriptor = open(path, O_EVTONLY)
//        let source = DispatchSource.makeFileSystemObjectSource(
//            fileDescriptor: fileDescriptor,
//            eventMask: .write,
//            queue: DispatchQueue.global()
//        )
//
//        source.setEventHandler {
//            print("Safari extension plist changed → check enable state")
//            // call getStateOfSafariExtension again here
//        }
//        source.resume()

    }
}

