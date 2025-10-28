//
//  ContentBlockerRequestHandler.swift
//  SelfControl Safari Extension
//
//  Created by Satendra Singh on 07/10/25.
//

import Foundation
import UniformTypeIdentifiers
import os.log

class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    // Must match the App Group used by the host app
    private let appGroup = "group.com.application.SelfControl.corebits"
    private let sharedFileName = "blockerList.json"

    func beginRequest(with context: NSExtensionContext) {
        ContentBlockerExtensionRequestHandler.handleRequest(with: context, groupIdentifier: appGroup)
        return
        let item = NSExtensionItem()

        // Try to load rules from the shared App Group container first
        if let sharedFileURL = sharedRulesFileURL(), FileManager.default.fileExists(atPath: sharedFileURL.path) {
            let provider = NSItemProvider(contentsOf: sharedFileURL)!
            item.attachments = [provider]
            context.completeRequest(returningItems: [item], completionHandler: nil)
            return
        }

        // Fallback: load bundled blockerList.json from the extension resources
        if let bundledURL = Bundle.main.url(forResource: "blockerList", withExtension: "json") {
            let provider = NSItemProvider(contentsOf: bundledURL)!
            item.attachments = [provider]
            context.completeRequest(returningItems: [item], completionHandler: nil)
            return
        }

        // If neither exists, return an empty rules array to avoid errors
//        let emptyRulesData = Data("[]".utf8)
//        let tmpURL = writeTempData(emptyRulesData, suggestedName: sharedFileName)
//        let provider = NSItemProvider(contentsOf: tmpURL)!
//        item.attachments = [provider]
//        context.completeRequest(returningItems: [item], completionHandler: nil)
    }

    // MARK: - Helpers

    private func sharedRulesFileURL() -> URL? {
        let fileManager = FileManager.default
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            NSLog("❌ App Group container not found for %@", appGroup)
            os_log("[SC] 🔍] Safari ❌ App Group container not found for: %{public}@", appGroup)
            return nil
        }
        return containerURL.appendingPathComponent(sharedFileName)
    }

    private func writeTempData(_ data: Data, suggestedName: String) -> URL {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let url = tmpDir.appendingPathComponent(suggestedName)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("❌ Failed to write temporary rules file: \(error.localizedDescription)")
            os_log("[SC] 🔍] Safari ❌ Failed to write temporary rules file: %{public}@", error.localizedDescription)

        }
        return url
    }
    
    
    func cancelRequest(withError error: any Error) {
        
        os_log("[SC] 🔍] Safari ❌ cancelRequeste: %{public}@", error.localizedDescription)

    }

}
