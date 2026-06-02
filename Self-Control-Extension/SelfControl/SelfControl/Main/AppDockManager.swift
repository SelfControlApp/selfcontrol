//
//  AppDockManager.swift
//  SelfControl
//
//  Created by Satendra Singh on 31/05/26.
//

import Cocoa

final class AppDockManager {
    var dockTimer: Timer?
    var timerFireDate: Date?
    
    func checAndStartShowDockTimer(endTime: Date) {
        timerFireDate = endTime
        if UserDefaults.standard.bool(forKey: "BadgeApplicationIcon") {
            dockTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateDockCountDown), userInfo: nil, repeats: true)
        } else {
            stopShowingCountDownInDock()
        }
    }
    
    func stopShowingCountDownInDock() {
        dockTimer?.invalidate()
        NSApp?.dockTile.badgeLabel = nil
    }
    
     @objc private func updateDockCountDown() {
        let blockEndingDate: Date = timerFireDate ?? .now
        let blockingSecond: Int = Int(blockEndingDate.timeIntervalSinceNow)
        var numSeconds: Int = Int(blockEndingDate.timeIntervalSinceNow)
         var numMinutes: Int = blockingSecond
         var numHours: Int = 0

        numHours = numSeconds / 3600
        numSeconds %= 3600
        numMinutes = numSeconds / 60
        numSeconds %= 60
           if blockingSecond > 0 {
            // Round up minutes when showing mm:ss style without seconds
            var minutes = numMinutes
            if numSeconds > 0 && minutes != 59 { minutes += 1 }

            let badgeString = String(format: "%02d:%02d", numHours, minutes)
            print("Badge: \(badgeString)")
            Task { @MainActor in
                ensureDockIconVisible()
                setDockBadge(badgeString)
            }
        } else {
            // Clear the badge when not using badging
            Task { @MainActor in
                setDockBadge(nil)
            }
        }
    }
    
    @MainActor
    func ensureDockIconVisible() {
        let app = NSApplication.shared
        if app.activationPolicy() != .regular {
            _ = app.setActivationPolicy(.regular)
        }
    }

    
    @MainActor
    func setDockBadge(_ text: String?) {
        // text: use nil to clear, non-empty string to show
        let app = NSApplication.shared
        app.dockTile.badgeLabel = (text?.isEmpty == false) ? text : nil
        app.dockTile.display()
    }
}
