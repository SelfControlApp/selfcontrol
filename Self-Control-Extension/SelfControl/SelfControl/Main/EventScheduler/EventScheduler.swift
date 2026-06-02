//
//  EventScheduler.swift
//  SelfControl
//
//  Created by Satendra Singh on 23/02/26.
//

import Foundation

//  A simple, concurrency-safe scheduler for recurring events by SCSCWeekday and time.
//  It validates time ranges and prevents overlapping events on the same day.

public enum SchedulerError: Error, LocalizedError, Equatable {
    case invalidTimeRange
    case conflict(conflictingEvents: [Event])
    case eventNotFound
    
    public var errorDescription: String? {
        switch self {
        case .invalidTimeRange:
            return "The start time must be earlier than the end time."
        case .conflict(let conflicts):
            let names = conflicts.map { $0.title }.joined(separator: ", ")
            return conflicts.isEmpty
                ? "The event conflicts with an existing event."
                : "The event conflicts with the following events: \(names)"
        case .eventNotFound:
            return "The event could not be found."
        }
    }
}

/// SCWeekday aligned with the user's Calendar (1 = Sunday in many locales).
/// We normalize to a fixed enumeration order (Monday...Sunday) for consistency.
public enum SCWeekday: Int, CaseIterable, Codable, Hashable, Sendable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1
    
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

    /// Returns the SCWeekday for a given Date using the provided Calendar.
    public static func from(date: Date, calendar: Calendar = .current) -> SCWeekday {
        let SCWeekdayNumber = calendar.component(.weekday, from: date)
        return SCWeekday(rawValue: SCWeekdayNumber) ?? .monday
    }
}

/// Represents a wall-clock time without a specific date or time zone.
/// Valid range: hour 0...23, minute 0...59
public struct TimeOfDay: Codable, Hashable, Sendable, Comparable {
    public let hour: Int
    public let minute: Int
    
    public init(hour: Int, minute: Int) {
        precondition((0...23).contains(hour), "Hour must be 0...23")
        precondition((0...59).contains(minute), "Minute must be 0...59")
        self.hour = hour
        self.minute = minute
    }
    
    public var minutesSinceMidnight: Int {
        hour * 60 + minute
    }
    
    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
    
    
    /// Total minutes since midnight (00:00).
    var totalMinutesSinceMidnight: Int {
        hour * 60 + minute
    }

    /// Returns the number of minutes from `other` to `self`.
    /// - Parameters:
    ///   - other: The starting time of day.
    ///   - wrapAroundMidnight: If true, negative differences will be wrapped
    ///     by adding 24 hours (1440 minutes). This is useful when you want the
    ///     forward difference within the same 24-hour cycle.
    /// - Returns: The minute difference as an `Int`.
    ///
    /// Examples:
    ///   - 10:30.minutes(from: 09:15) == 75
    ///   - 01:00.minutes(from: 23:30,
    ///   wrapAroundMidnight: true) == 90
    ///   - 01:00.minutes(from: 23:30, wrapAroundMidnight: false) == -1410
    func minutes(from other: TimeOfDay, wrapAroundMidnight: Bool = false) -> Int {
        let diff = self.totalMinutesSinceMidnight - other.totalMinutesSinceMidnight
        guard wrapAroundMidnight, diff < 0 else { return diff }
        return diff + 24 * 60
    }

    /// Convenience: minutes until another time (alias with reversed arguments).
    /// Positive when `other` is later than `self` on the same day.
    func minutes(until other: TimeOfDay, wrapAroundMidnight: Bool = false) -> Int {
        other.minutes(from: self, wrapAroundMidnight: wrapAroundMidnight)
    }
    
    public func formatted(locale: Locale = .current) -> String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let cal = Calendar(identifier: .gregorian)
        let date = cal.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

/// A recurring event that happens on one or more SCWeekdays at a given time range.
public struct Event: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String = ""
    public var days: Set<SCWeekday>
    public var startTime: TimeOfDay
    public var endTime: TimeOfDay
    public var userInfo: [String: String]? // Optional metadata
    
    public init(
        id: UUID = UUID(),
        title: String = "",
        days: Set<SCWeekday>,
        startTime: TimeOfDay,
        endTime: TimeOfDay,
        userInfo: [String: String]? = nil
    ) throws {
        guard startTime < endTime else {
            throw SchedulerError.invalidTimeRange
        }
        self.id = id
        self.title = title
        self.days = days
        self.startTime = startTime
        self.endTime = endTime
        self.userInfo = userInfo
    }
    
    /// Returns true if this event occurs on the given SCWeekday.
    public func occurs(on day: SCWeekday) -> Bool {
        days.contains(day)
    }
    
    /// Overlap check with another event on a specific SCWeekday.
    /// Adjacent ranges (end == start) are not considered overlapping.
    public func overlaps(with other: Event, on day: SCWeekday) -> Bool {
        guard self.occurs(on: day), other.occurs(on: day) else { return false }
        let aStart = self.startTime.minutesSinceMidnight
        let aEnd = self.endTime.minutesSinceMidnight
        let bStart = other.startTime.minutesSinceMidnight
        let bEnd = other.endTime.minutesSinceMidnight
        return aStart < bEnd && aEnd > bStart
    }
}
