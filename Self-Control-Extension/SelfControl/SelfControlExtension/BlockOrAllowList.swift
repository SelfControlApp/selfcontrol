//
//  BlockOrAllowList.swift
//  SelfControl
//
//  Created by Satendra Singh on 24/09/25.
//


import Foundation
import os.log
import NetworkExtension

class BlockOrAllowList: NSObject {

    // MARK: - Properties
    
    var items: Set<String>
//    var lastModified: Date?
    
    // Serial queue for thread safety (replace @synchronized)
//    private let queue = DispatchQueue(label: "BlockOrAllowList.serial")

    // MARK: - Initializer

    init(items: [String]) {
        self.items = Set(items)
        super.init()
    }

    // MARK: - Methods
    
//    var isRemote: Bool {
//        return path.hasPrefix("http://") || path.hasPrefix("https://")
//    }

//    func load(_ path: String) {
//        queue.sync {
//            self.path = path
//            self.items.removeAll()
//
//            guard !path.isEmpty else {
//                os_log("no list specified...", log: .default, type: .debug)
//                return
//            }
//            
//            var listString: String?
//            var error: Error?
//            
//            if isRemote {
//                os_log("(re)loading (remote) list", log: .default, type: .debug)
//                if let url = URL(string: path) {
//                    do {
//                        listString = try String(contentsOf: url, encoding: .utf8)
//                    } catch let e {
//                        error = e
//                    }
//                }
//                if let error = error {
//                    os_log("ERROR: failed to (re)load (remote) list, %{public}@ (error: %{public}@)", log: .default, type: .error, path, String(describing: error))
//                    return
//                }
//                // (Re)load remote URL once a day
//                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 24*60*60) {
//                    self.load(self.path)
//                }
//            } else {
//                os_log("(re)loading (local) list, %{public}@", log: .default, type: .debug, path)
//                do {
//                    listString = try String(contentsOfFile: path, encoding: .utf8)
//                } catch let e {
//                    error = e
//                }
//                if let error = error {
//                    os_log("ERROR: failed to (re)load (local) list, %{public}@ (error: %{public}@)", log: .default, type: .error, path, String(describing: error))
//                    return
//                }
//                if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
//                   let fileModified = attrs[.modificationDate] as? Date {
//                    self.lastModified = fileModified
//                }
//            }
//
//            if let listString = listString {
//                let lines = listString.components(separatedBy: .newlines)
//                let filtered = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
//                    .filter { !$0.isEmpty && !$0.hasPrefix("#") }
//                self.items = Set(filtered)
//                os_log("SC] 🔍(re)loaded %lu list items", log: .default, type: .debug, self.items.count)
//            }
//        }
//    }

    /// Check if flow matches item on block or allow list
    func isMatch(_ flow: NEFilterSocketFlow) -> Bool {
        // Only access properties and perform mutation in the queue (thread safety)
//        return queue.sync {

            var endpointNames = Set<String>()
            
            // Get remote endpoint host
            if let url = flow.url, let urlString = url.absoluteString.lowercased() as String? {
                endpointNames.insert(urlString)
            }
            if let url = flow.url, let host = url.host?.lowercased() {
                endpointNames.insert(host)
            }
            if let remoteEndpoint = flow.remoteEndpoint as? NWHostEndpoint {
                endpointNames.insert(remoteEndpoint.hostname.lowercased())
            }

            // macOS 11+ specific property
            if #available(macOS 11, *) {
                if let remoteHostname = flow.remoteHostname?.lowercased() {
                    endpointNames.insert(remoteHostname)
                    if remoteHostname.hasPrefix("www.") {
                        let noWWW = String(remoteHostname.dropFirst(4))
                        endpointNames.insert(noWWW)
                    }
                }
            }
        os_log("[SC] 🔍] BlockList endpoint names : %{public}@", log: OSLog.default, type: .info, endpointNames.debugDescription)

            // Find matches
            let matches = items.intersection(endpointNames)
            if !matches.isEmpty {
                os_log("SC] 🔍 endpoint names %{public}@ matched the following list items %{public}@", log: .default, type: .debug, String(describing: endpointNames), String(describing: matches))
                return true
            }

            return false
//        }
    }
}

// MARK: - NEFilterSocketFlow Extensions

//extension NEFilterSocketFlow {
//    /// You must implement these extensions if your Objective-C code provides them!
//    @objc public override var url: URL? {
//        // Implement according to your codebase (category/extension in Objective-C)
//        return nil // Placeholder
//    }
//    @objc var remoteHostname: String? {
//        // Implement according to your codebase (category/extension in Objective-C)
//        return nil // Placeholder
//    }
//}
