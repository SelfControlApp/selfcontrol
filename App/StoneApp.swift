import SwiftUI

@main
struct StoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(width: 420, height: 320)
                .onAppear {
                    appDelegate.appController.start()
                    SCScheduleManager.shared.syncAllLaunchdAgents()
                }
        }
    }
}
