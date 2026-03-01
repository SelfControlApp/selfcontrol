//
//  EventScheduler.swift
//
//  A simple, concurrency-safe scheduler for recurring events by weekday and time.
//  It validates time ranges and prevents overlapping events on the same day.
//

import Foundation

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

/// Weekday aligned with the user's Calendar (1 = Sunday in many locales).
/// We normalize to a fixed enumeration order (Monday...Sunday) for consistency.
public enum Weekday: Int, CaseIterable, Codable, Hashable, Sendable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1
    
    public var displayName: String {
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
    
    /// Returns the Weekday for a given Date using the provided Calendar.
    public static func from(date: Date, calendar: Calendar = .current) -> Weekday {
        let weekdayNumber = calendar.component(.weekday, from: date)
        return Weekday(rawValue: weekdayNumber) ?? .monday
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

/// A recurring event that happens on one or more weekdays at a given time range.
public struct Event: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var days: Set<Weekday>
    public var startTime: TimeOfDay
    public var endTime: TimeOfDay
    public var userInfo: [String: String]? // Optional metadata
    
    public init(
        id: UUID = UUID(),
        title: String,
        days: Set<Weekday>,
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
    
    /// Returns true if this event occurs on the given weekday.
    public func occurs(on day: Weekday) -> Bool {
        days.contains(day)
    }
    
    /// Overlap check with another event on a specific weekday.
    /// Adjacent ranges (end == start) are not considered overlapping.
    public func overlaps(with other: Event, on day: Weekday) -> Bool {
        guard self.occurs(on: day), other.occurs(on: day) else { return false }
        let aStart = self.startTime.minutesSinceMidnight
        let aEnd = self.endTime.minutesSinceMidnight
        let bStart = other.startTime.minutesSinceMidnight
        let bEnd = other.endTime.minutesSinceMidnight
        return aStart < bEnd && aEnd > bStart
    }
}

/// A concurrency-safe scheduler to add, update, and query recurring events by weekday and time.
public actor EventScheduler {
    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }
    
    private let calendar: Calendar
    private var eventsByID: [UUID: Event] = [:]
    
    // MARK: - CRUD
    
    /// Schedules a new event. Throws if the time range is invalid or conflicts with existing events.
    @discardableResult
    public func schedule(
        title: String,
        days: Set<Weekday>,
        startTime: TimeOfDay,
        endTime: TimeOfDay,
        userInfo: [String: String]? = nil
    ) throws -> Event {
        let newEvent = try Event(title: title, days: days, startTime: startTime, endTime: endTime, userInfo: userInfo)
        try assertNoConflicts(with: newEvent, excludingID: nil)
        eventsByID[newEvent.id] = newEvent
        return newEvent
    }
    
    /// Updates an existing event. Throws if not found or if the updated event conflicts.
    public func update(
        id: UUID,
        title: String? = nil,
        days: Set<Weekday>? = nil,
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
    
    /// Returns events that occur on the specified weekday, sorted by start time.
    public func events(on day: Weekday) -> [Event] {
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
            let weekday = Weekday.from(date: candidateDay, calendar: calendar)
            guard event.occurs(on: weekday) else { continue }
            
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
