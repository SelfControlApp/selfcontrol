//
//  AppMover.swift
//  SelfControl
//
//  Created by Satendra Singh on 05/12/25.
//

import Cocoa
import os.log
import Darwin

final class AppMover {

    static func moveIfNeeded() {
        let fm = FileManager.default
        let originalBundleURL = Bundle.main.bundleURL
        let bundleURL = (try? originalBundleURL.resolvingSymlinksInPath()) ?? originalBundleURL

        os_log("[SC] 🔍 AppMover.moveIfNeeded bundle: %@", log: OSLog.default, type: .info, bundleURL.path)

        // 1. If already in Applications (system or user), do nothing.
        if isInApplicationsFolder(bundleURL) {
            os_log("[SC] ✅ App is already in Applications, skipping move.", log: OSLog.default, type: .info)
            return
        }

        // 2. Determine preferred Applications destination.
        guard let destinationAppDir = preferredApplicationsDirectory() else {
            os_log("[SC] ⚠️ Could not determine Applications directory, skipping move.", log: OSLog.default, type: .error)
            return
        }

        // Ensure ~/Applications exists when chosen as destination.
        if destinationAppDir.path.hasPrefix(fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path) {
            do {
                try fm.createDirectory(at: destinationAppDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                os_log("[SC] ❌ Could not create user Applications directory: %@", log: OSLog.default, type: .error, error.localizedDescription)
                return
            }
        }

        // 3. Prompt the user to move.
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Move to Applications Folder?"
            alert.informativeText = "Would you like to move this app to your Applications folder? It must quit and relaunch."
            alert.addButton(withTitle: "Move to Applications Folder")
            alert.addButton(withTitle: "Do Not Move")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                performMove(to: destinationAppDir, bundleURL: bundleURL)
            } else {
                os_log("[SC] 🚫 User chose not to move the app.", log: OSLog.default, type: .info)
            }
        }
    }

    private static func performMove(to appDir: URL, bundleURL: URL) {
        let fm = FileManager.default
        os_log("[SC] 🔧 AppMover.performMove from: %@ → %@", log: OSLog.default, type: .info, bundleURL.path, appDir.path)

        // Destination path for the app
        let destURL = appDir.appendingPathComponent(bundleURL.lastPathComponent, isDirectory: true)

        // If a copy already exists at destination, try to trash it to avoid conflicts.
        if fm.fileExists(atPath: destURL.path) {
            do {
                var resultingURL: NSURL?
                try fm.trashItem(at: destURL, resultingItemURL: &resultingURL)
                os_log("[SC] 🗑️ Trashed existing app at destination.", log: OSLog.default, type: .info)
            } catch {
                os_log("[SC] ⚠️ Could not trash existing app. Attempting removal: %@", log: OSLog.default, type: .error, error.localizedDescription)
                do {
                    try fm.removeItem(at: destURL)
                } catch {
                    os_log("[SC] ❌ Could not remove existing app at destination: %@", log: OSLog.default, type: .error, error.localizedDescription)
                    return
                }
            }
        }

        // Copy (not move) the running app bundle. Moving a running app may fail (e.g., from a read-only DMG).
        do {
            try fm.copyItem(at: bundleURL, to: destURL)
            os_log("[SC] ✅ Copied app to Applications.", log: OSLog.default, type: .info)
        } catch {
            os_log("[SC] ❌ Error copying app to Applications: %@", log: OSLog.default, type: .error, error.localizedDescription)
            return
        }

        // Clear quarantine attribute on the copied app so Gatekeeper doesn't warn again.
        removeQuarantineRecursively(at: destURL)

        // Attempt to remove (trash) the original copy now that the app has been copied.
        attemptToRemoveOriginal(at: bundleURL)

        // Relaunch the copied app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: destURL, configuration: config) { _, err in
                if let err = err {
                    os_log("[SC] ❌ Failed to relaunch moved app: %@", log: OSLog.default, type: .error, err.localizedDescription)
                } else {
                    os_log("[SC] 🚀 Relaunched moved app successfully.", log: OSLog.default, type: .info)
                }

                // Terminate current instance regardless; the copy succeeded.
                if NSApp != nil {
                    NSApp.terminate(nil)
                } else {
                    exit(0)
                }
            }
        })
    }

    private static func removeQuarantineAttribute(from url: URL) {
        let path = url.path
        let attrName = "com.apple.quarantine"

        // Check if attribute exists
        let hasAttr = getxattr(path, attrName, nil, 0, 0, 0) >= 0
        if hasAttr {
            // Attempt to remove the attribute; ignore failure.
            let result = removexattr(path, attrName, 0)
            if result == 0 {
                os_log("[SC] 🧹 Removed quarantine attribute: %@", log: OSLog.default, type: .debug, path)
            } else {
                os_log("[SC] ⚠️ Failed to remove quarantine attribute: %@", log: OSLog.default, type: .debug, path)
            }
        }
    }

    private static func removeQuarantineRecursively(at url: URL) {
        let fm = FileManager.default

        // Walk the bundle contents
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                removeQuarantineAttribute(from: fileURL)
            }
        }
        // Also clear on the root bundle directory
        removeQuarantineAttribute(from: url)
    }

    private static func attemptToRemoveOriginal(at sourceBundleURL: URL) {
        let fm = FileManager.default

        // Never try to remove if already in Applications (safety)
        if isInApplicationsFolder(sourceBundleURL) {
            return
        }

        // Prefer moving to Trash so user can recover; if that fails, try direct removal.
        do {
            var trashedURL: NSURL?
            try fm.trashItem(at: sourceBundleURL, resultingItemURL: &trashedURL)
            os_log("[SC] 🗑️ Trashed original app at: %@", log: OSLog.default, type: .info, sourceBundleURL.path)
        } catch {
            os_log("[SC] ⚠️ Could not trash original app (%@). Attempting direct removal.", log: OSLog.default, type: .error, error.localizedDescription)
            do {
                try fm.removeItem(at: sourceBundleURL)
                os_log("[SC] ✅ Removed original app at: %@", log: OSLog.default, type: .info, sourceBundleURL.path)
            } catch {
                // This commonly fails if the app is on a read-only volume (e.g., a DMG).
                os_log("[SC] ❌ Failed to remove original app: %@", log: OSLog.default, type: .error, error.localizedDescription)
            }
        }
    }
}

// MARK: - Helpers

private extension AppMover {
    static func preferredApplicationsDirectory() -> URL? {
        let fm = FileManager.default
        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let userApplications = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)

        // Prefer /Applications if writable, otherwise fallback to ~/Applications.
        if fm.isWritableFile(atPath: systemApplications.path) {
            return systemApplications
        } else {
            return userApplications
        }
    }

    static func isInApplicationsFolder(_ bundleURL: URL) -> Bool {
        let fm = FileManager.default
        let parent = bundleURL.deletingLastPathComponent()

        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let userApplications = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)

        // Compare after resolving symlinks for reliability
        let resolvedParent = (try? parent.resolvingSymlinksInPath()) ?? parent
        let resolvedSystem = (try? systemApplications.resolvingSymlinksInPath()) ?? systemApplications
        let resolvedUser = (try? userApplications.resolvingSymlinksInPath()) ?? userApplications

        if resolvedParent == resolvedSystem || resolvedParent == resolvedUser {
            return true
        }

        // Additional guard: some volumes may present Applications differently; fall back to path prefix check.
        let path = resolvedParent.path
        if path == "/Applications" || path.hasSuffix("/Applications") {
            return true
        }

        return false
    }
}
