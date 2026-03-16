import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    let appController = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        appController.start()
        appController.showMainWindow()

        SCScheduleManager.shared.syncAllLaunchdAgents()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running if timer window is visible (block in progress)
        if let timerWindow = appController.timerWindowController?.window, timerWindow.isVisible {
            return false
        }
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if SCBlockUtilities.anyBlockIsRunning() {
                appController.refreshUserInterface()
            } else {
                appController.showMainWindow()
            }
        }
        return true
    }
}
