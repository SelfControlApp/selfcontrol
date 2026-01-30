//
//  ScheduleBlockManager.swift
//  SelfControl
//
//  Created by Satendra Singh on 29/01/26.
//

final class ScheduleBlockManager {
    private var schedules: [Schedule] = []
    @MainActor
    final class BlockedURLStore: ObservableObject {
        
        @Published
        private(set) var schedules: [Schedule] = []
        
        init() {
            _ = loadSchedules()
        }
        
        // Load schedules from UserDefaults
        private func loadSchedules() -> [Schedule] {
            if let data = UserDefaults.standard.data(forKey: "schedules"),
               let decoded = try? JSONDecoder().decode([Schedule].self, from: data) {
                schedules = decoded
            } else {
                // Initialize with one empty schedule if no saved data
                schedules = [Schedule(timeSlots: [], enabledDays: [])]
            }
            return schedules
        }
        
        // Save schedules to UserDefaults
        private func saveSchedules(schedules: [Schedule]) {
            if let encoded = try? JSONEncoder().encode(schedules) {
                UserDefaults.standard.set(encoded, forKey: "schedules")
            }
        }
    }
}
