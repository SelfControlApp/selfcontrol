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
    
    init(id: UUID = UUID(), domain: String, paths: [String] = [], isEnabled: Bool = true) {
        self.id = id
        self.domain = domain
        self.paths = paths
        self.isEnabled = isEnabled
    }
    
    var urls: [String]? {
        if isEnabled == false { return nil }
        if paths.count == 0 {
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

// MARK: - Schedule Models
struct TimeSlot: Identifiable, Codable, Equatable {
    let id: UUID
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    
    init(id: UUID = UUID(), startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.id = id
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }
    
    // Helper to format hour in 12-hour format
    private func formatHour12(_ hour24: Int) -> (hour: Int, isPM: Bool) {
        if hour24 == 0 {
            return (12, false)
        } else if hour24 < 12 {
            return (hour24, false)
        } else if hour24 == 12 {
            return (12, true)
        } else {
            return (hour24 - 12, true)
        }
    }
    
    var startTimeString: String {
        let (hour12, isPM) = formatHour12(startHour)
        let amPm = isPM ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour12, startMinute, amPm)
    }
    
    var endTimeString: String {
        let (hour12, isPM) = formatHour12(endHour)
        let amPm = isPM ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour12, endMinute, amPm)
    }
    
    var displayString: String {
        "\(startTimeString)-\(endTimeString)"
    }
}

// MARK: - Weekday
enum Weekday: Int, CaseIterable, Codable, Hashable {
    case monday = 0
    case tuesday = 1
    case wednesday = 2
    case thursday = 3
    case friday = 4
    case saturday = 5
    case sunday = 6
    
    var letter: String {
        switch self {
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        case .sunday: return "S"
        }
    }
    
    var fullName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }
}

// MARK: - Schedule
struct Schedule: Identifiable, Codable, Equatable {
    let id: UUID
    var timeSlots: [TimeSlot]
    var enabledDays: Set<Weekday>
    var isExpanded: Bool
    var isEnabled: Bool
    
    init(id: UUID = UUID(), timeSlots: [TimeSlot] = [], enabledDays: Set<Weekday> = [], isExpanded: Bool = false, isEnabled: Bool = false) {
        self.id = id
        self.timeSlots = timeSlots
        self.enabledDays = enabledDays
        self.isExpanded = isExpanded
        self.isEnabled = isEnabled
    }
    
    var summaryString: String {
        timeSlots.map { $0.displayString }.joined(separator: " ")
    }
    
    var enabledDaysString: String {
        Weekday.allCases.compactMap { enabledDays.contains($0) ? $0.letter : nil }.joined()
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
