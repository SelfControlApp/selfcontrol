import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    let appController = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI handles window creation via WindowGroup.
        // AppDelegate is used via NSApplicationDelegateAdaptor for AppKit-specific needs.
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
