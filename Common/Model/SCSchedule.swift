import Foundation

/// A recurring scheduled block definition.
struct SCSchedule: Codable, Identifiable {
    var id: String
    var name: String
    var weekdays: [Int] // 0=Sun through 6=Sat
    var hour: Int
    var minute: Int
    var durationMinutes: Int
    var blocklist: [String]
    var enabled: Bool

    init(id: String = UUID().uuidString,
         name: String = "",
         weekdays: [Int] = [],
         hour: Int = 9,
         minute: Int = 0,
         durationMinutes: Int = 60,
         blocklist: [String] = [],
         enabled: Bool = true) {
        self.id = id
        self.name = name
        self.weekdays = weekdays
        self.hour = hour
        self.minute = minute
        self.durationMinutes = durationMinutes
        self.blocklist = blocklist
        self.enabled = enabled
    }

    /// The launchd job label for this schedule.
    var launchdLabel: String {
        "\(StoneConstants.scheduleLaunchdPrefix).\(id)"
    }
}
