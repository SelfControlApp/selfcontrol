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
    
//    public var displayName: String {
//        switch self {
//        case .monday: return "Monday"
//        case .tuesday: return "Tuesday"
//        case .wednesday: return "Wednesday"
//        case .thursday: return "Thursday"
//        case .friday: return "Friday"
//        case .saturday: return "Saturday"
//        case .sunday: return "Sunday"
//        }
//    }
    
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

/// A concurrency-safe scheduler to add, update, and query recurring events by SCWeekday and time.
public actor EventScheduler {
    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }
    
    public let calendar: Calendar
    private var eventsByID: [UUID: Event] = [:]
    
    // MARK: - CRUD
    
    /// Schedules a new event. Throws if the time range is invalid or conflicts with existing events.
    @discardableResult
    public func schedule(
        title: String = "",
        days: Set<SCWeekday>,
        startTime: TimeOfDay,
        endTime: TimeOfDay,
        userInfo: [String: String]? = nil
    ) throws -> Event {
        let newEvent = try Event(title: title, days: days, startTime: startTime, endTime: endTime, userInfo: userInfo)
        try assertNoConflicts(with: newEvent, excludingID: nil)
        eventsByID[newEvent.id] = newEvent
        return newEvent
    }

    @discardableResult
    public func schedule(
        newEvent: Event
    ) throws -> Event {
        try assertNoConflicts(with: newEvent, excludingID: nil)
        eventsByID[newEvent.id] = newEvent
        return newEvent
    }

    /// Updates an existing event. Throws if not found or if the updated event conflicts.
    public func update(
        id: UUID,
        title: String? = nil,
        days: Set<SCWeekday>? = nil,
        startTime: TimeOfDay? = nil,
        endTime: TimeOfDay? = nil,
        userInfo: [String: String]? = nil
    ) throws -> Event {
        guard var existing = eventsByID[id] else {
            throw SchedulerError.eventNotFound
        }
        
        let newTitle = title ?? existing.title
        let newDays = days ?? existing.days
        let newStart = startTime ?? existing.startTime
        let newEnd = endTime ?? existing.endTime
        let newUserInfo = userInfo ?? existing.userInfo
        
        let updated = try Event(id: id, title: newTitle, days: newDays, startTime: newStart, endTime: newEnd, userInfo: newUserInfo)
        try assertNoConflicts(with: updated, excludingID: id)
        eventsByID[id] = updated
        return updated
    }
    
    /// Removes an event by ID. Returns the removed event or throws if not found.
    @discardableResult
    public func remove(id: UUID) throws -> Event {
        guard let removed = eventsByID.removeValue(forKey: id) else {
            throw SchedulerError.eventNotFound
        }
        return removed
    }
    
    /// Returns all scheduled events sorted by title.
    public func allEvents() -> [Event] {
        eventsByID.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    
    /// Returns events that occur on the specified SCWeekday, sorted by start time.
    public func events(on day: SCWeekday) -> [Event] {
        eventsByID.values
            .filter { $0.occurs(on: day) }
            .sorted { lhs, rhs in
                if lhs.startTime == rhs.startTime {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.startTime < rhs.startTime
            }
    }
    
    // MARK: - Conflict Checking
    
    /// Returns any events that would conflict with the provided event.
    public func conflicts(for event: Event, excludingID: UUID? = nil) -> [Event] {
        eventsByID.values
            .filter { existing in
                if let exclude = excludingID, existing.id == exclude { return false }
                // Only check days that overlap
                let sharedDays = existing.days.intersection(event.days)
                guard !sharedDays.isEmpty else { return false }
                return sharedDays.contains { event.overlaps(with: existing, on: $0) }
            }
            .sorted { $0.startTime < $1.startTime }
    }
    
    private func assertNoConflicts(with event: Event, excludingID: UUID?) throws {
        let conflicts = conflicts(for: event, excludingID: excludingID)
        if !conflicts.isEmpty {
            throw SchedulerError.conflict(conflictingEvents: conflicts)
        }
    }
    
    // MARK: - Query Helpers
    
    /// Returns the next DateInterval this event will occur after the given date, if any.
    /// This uses the scheduler's calendar to resolve the next occurrence in the current week or later.
    public func nextOccurrence(of eventID: UUID, after date: Date = Date()) -> DateInterval? {
        guard let event = eventsByID[eventID] else { return nil }
        return nextOccurrence(of: event, after: date)
    }
    
    /// Returns the next DateInterval an event will occur after the given date, if any.
    public func nextOccurrence(of event: Event, after date: Date = Date()) -> DateInterval? {
        // Search up to 8 weeks ahead to be safe for unusual calendars
        for dayOffset in 0..<(7 * 8) {
            guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let SCWeekday = SCWeekday.from(date: candidateDay, calendar: calendar)
            guard event.occurs(on: SCWeekday) else { continue }
            
            var comps = calendar.dateComponents([.year, .month, .day], from: candidateDay)
            comps.hour = event.startTime.hour
            comps.minute = event.startTime.minute
            comps.second = 0
            let start = calendar.date(from: comps)
            
            comps.hour = event.endTime.hour
            comps.minute = event.endTime.minute
            let end = calendar.date(from: comps)
            
            if let start, let end, end > date {
                // If the start is in the past but end is in the future, return the remaining portion.
                let actualStart = max(start, date)
                return DateInterval(start: actualStart, end: end)
            }
        }
        return nil
    }
}
