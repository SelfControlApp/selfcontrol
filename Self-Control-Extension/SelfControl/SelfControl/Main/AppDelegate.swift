//
//  AppDelegate.swift
//  SelfControl
//
//  Created by Satendra Singh on 11/01/26.
//


import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    var onAppClose: (() -> Void)?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App did finish launching")
        enableHelper()
        AppMover.moveIfNeeded()
        LocalNotificationManager.requestAuthorization()
    }
    
    private func enableHelper() {
            Task {
                do {
                    try await HelperConnection.shared.installLoginItemIfNeeded()
                    HelperConnection.shared.connect()
                } catch {
                    print("installLoginItemIfNeeded Error: \(error)")
                }
//                let error =
//                print("Install Error: \(String(describing: error))")
            }
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("App will terminate")
        onAppClose?()
        // Save state, cleanup resources, stop services, etc.
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("Should terminate")
        return .terminateNow
    }
}
