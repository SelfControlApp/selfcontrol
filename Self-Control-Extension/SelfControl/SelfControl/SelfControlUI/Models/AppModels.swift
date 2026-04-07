//
//  AppModels.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import Foundation

// MARK: - Blocked URL Model
struct BlockedURL: Identifiable, Codable, Equatable {
    let id: UUID
    var domain: String
    var paths: [String]
    var isEnabled: Bool
    var blockEntireDomain: Bool

    init(id: UUID = UUID(), domain: String, paths: [String] = [], isEnabled: Bool = true, blockEntireDomain: Bool = false) {
        self.id = id
        self.domain = domain
        self.paths = paths
        self.isEnabled = isEnabled
        self.blockEntireDomain = blockEntireDomain
    }
    
    var urls: [String]? {
        if isEnabled == false { return nil }
        if paths.count == 0 || blockEntireDomain {
            return [domain]
        } else {
            return paths.map { path in
                let path = path.hasPrefix("/") ? path : "/\(path)"
                return "\(domain)\(path)"
            }
        }
    }
}

// MARK: - App Navigation
enum AppScreen: Equatable {
    case main
    case editList
    case domainDetail(UUID)
    case advancedSettings
    case blockSchedule
    case about
    
    static func == (lhs: AppScreen, rhs: AppScreen) -> Bool {
        switch (lhs, rhs) {
        case (.main, .main):
            return true
        case (.editList, .editList):
            return true
        case (.domainDetail(let lhsId), .domainDetail(let rhsId)):
            return lhsId == rhsId
        case (.advancedSettings, .advancedSettings):
            return true
        case (.blockSchedule, .blockSchedule):
            return true
        case (.about, .about):
            return true
        default:
            return false
        }
    }
}

// MARK: - Blocking Mode
enum BlockingMode: String {
    case blocklist
    case allowlist
}

// MARK: - Intensity Level
enum IntensityLevel: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "Stop blocking anytime with one click."
        case .medium:
            return "Added friction with a 10 minute wait."
        case .high:
            return "No way to stop blocking early."
        }
    }
}


// MARK: - About Page Item
enum AboutItemType {
    case text
    case link
}

struct AboutItem {
    let type: AboutItemType
    let text: String
    let url: String?
    
    init(text: String) {
        self.type = .text
        self.text = text
        self.url = nil
    }
    
    init(text: String, url: String) {
        self.type = .link
        self.text = text
        self.url = url
    }
}

// MARK: - Tip Model
struct Tip: Identifiable {
    let id: UUID
    let title: String
    let description: String
    
    init(id: UUID = UUID(), title: String, description: String) {
        self.id = id
        self.title = title
        self.description = description
    }
}
