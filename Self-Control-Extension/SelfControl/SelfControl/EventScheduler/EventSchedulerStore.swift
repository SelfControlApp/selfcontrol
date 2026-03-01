//
//  EventSchedulerStore.swift
//  SelfControl
//
//  Created by Satendra Singh on 25/02/26.
//

struct EventSchedulerStore {
    // Load schedules from UserDefaults
    static func loadSchedules() -> [Schedule] {
        if let data = UserDefaults.standard.data(forKey: "schedules"),
           let decoded = try? JSONDecoder().decode([Schedule].self, from: data) {
            return decoded
        } else {
            // Initialize with one empty schedule if no saved data
            return [Schedule(timeSlots: [], enabledDays: [])]
        }
    }
    
    // Save schedules to UserDefaults
    static func saveSchedules(schedules: [Schedule]) {
        if let encoded = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(encoded, forKey: "schedules")
        }
    }
}

// MARK: - Schedule
struct Schedule: Identifiable, Codable, Equatable {
    let id: UUID
    var timeSlots: [TimeSlot]
    var enabledDays: Set<SCWeekday>
    var isExpanded: Bool
    var isEnabled: Bool
    
    init(id: UUID = UUID(), timeSlots: [TimeSlot] = [], enabledDays: Set<SCWeekday> = [], isExpanded: Bool = false, isEnabled: Bool = false) {
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
        SCWeekday.allCases.compactMap { enabledDays.contains($0) ? $0.letter : nil }.joined()
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
