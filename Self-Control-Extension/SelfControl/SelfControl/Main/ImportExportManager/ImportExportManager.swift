//
//  ImportExportManager.swift
//  SelfControl
//
//  Created by Satendra Singh on 21/02/26.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

// Define your app-specific UTType.
// Make sure this matches the exported UTI you declare in your Info.plist.

extension UTType {
    static let blockedURLList = UTType(exportedAs: "scbulist")
}

struct ImportExportManager {
    
    @MainActor
    static func exportBlockedUrls(blockedURLs: [BlockedURL]) {
        // Require a single, concrete format. Here we use JSON for the payload,
        // but the on-disk file type is your custom UTType.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(blockedURLs)
        } catch {
            NSLog("Failed to encode blocked URLs: \(error.localizedDescription)")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Blocked URLs"
        panel.nameFieldStringValue = "BlockedURLs.scbulist" // Use your app’s extension
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.blockedURLList]
        } else {
            // Fallback for older macOS: still restrict by extension
            panel.allowedFileTypes = ["scbulist"]
        }
        panel.isExtensionHidden = false
        panel.canCreateDirectories = true

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Failed to write blocked URLs to file: \(error.localizedDescription)")
        }
    }

    @MainActor
    static func importBlockedUrls(presentingWindow: NSWindow? = nil) async throws -> [BlockedURL] {
        let panel = NSOpenPanel()
        panel.title = "Import Blocked URLs"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        panel.canCreateDirectories = false
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.blockedURLList]
        } else {
            // Fallback for older macOS: restrict by your app’s extension
            panel.allowedFileTypes = ["scbulist"]
        }

        let response: NSApplication.ModalResponse
        if let window = presentingWindow {
            response = await withCheckedContinuation { continuation in
                panel.beginSheetModal(for: window) { result in
                    continuation.resume(returning: result)
                }
            }
        } else {
            response = panel.runModal()
        }

        guard response == .OK, let url = panel.url else {
            // User cancelled
            throw CocoaError(.userCancelled)
        }

        // Optional extra validation of the picked file’s type
//        if #available(macOS 11.0, *),
//           let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
//           type != .blockedURLList {
//            throw NSError(domain: "ImportBlockedURLs", code: 1, userInfo: [
//                NSLocalizedDescriptionKey: "The selected file is not a valid Blocked URL List."
//            ])
//        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let blocked = try decoder.decode([BlockedURL].self, from: data)
        return blocked
    }
}
