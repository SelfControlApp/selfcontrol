//
//  CheckProcess.swift
//  SelfControl
//
//  Created by Satendra Singh on 21/05/26.
//


import AppKit

struct CheckProcess {

    var bundleID: String
    var processName: String

    func isRunning() -> Bool {
        // Use the bundle identifier if possible (most reliable).
        if isAppRunning(bundleIdentifier: bundleID) {
            fputs("Installation aborted: \(bundleID) is currently running.\n", stderr)
            return true
        }

        // Optional: also guard by process name as a fallback.
        if isProcessRunningByName(processName) {
            fputs("Installation aborted: process '\(processName)' is currently running.\n", stderr)
           return true
        }

        // OK to proceed
        return false
    }

    private func isAppRunning(bundleIdentifier: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    private func isProcessRunningByName(_ name: String) -> Bool {
        // Uses /usr/bin/pgrep -x for exact match
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-x", name]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
