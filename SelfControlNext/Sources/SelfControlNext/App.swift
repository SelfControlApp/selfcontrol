import AppKit
import SwiftUI


struct SelfControlNextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("SelfControl", id: "main") {
            ContentView()
                .environment(delegate.store)
                .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 980, height: 700)
        .windowToolbarStyle(.unified)

        MenuBarExtra(isInserted: Binding(
            get: { delegate.store.config.settings.showMenuBarItem },
            // Only write real changes; a no-op write would re-trigger the scene and loop forever.
            set: { if delegate.store.config.settings.showMenuBarItem != $0 { delegate.store.config.settings.showMenuBarItem = $0 } }
        )) {
            MenuBarView().environment(delegate.store)
        } label: {
            Image(systemName: "hourglass")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()
    private lazy var monitor = Monitor(store: store)
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opt out of App Nap: throttled timers would miss heartbeats to the helper and pause tracking.
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep],
                                                         reason: "Tracking app usage and enforcing limits")
        monitor.start()
    }

    /// Keep enforcing limits after the window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveAll()
    }
}
