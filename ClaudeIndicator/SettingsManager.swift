import Foundation

class SettingsManager {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard
    private let timeWindowKey = "sessionTimeWindowMinutes"

    // Default to 60 minutes (1 hour)
    var sessionTimeWindowMinutes: Int {
        get {
            let value = defaults.integer(forKey: timeWindowKey)
            return value == 0 ? 60 : value
        }
        set {
            defaults.set(newValue, forKey: timeWindowKey)
        }
    }

    // Convert to seconds for easy comparison
    var sessionTimeWindowSeconds: TimeInterval {
        return TimeInterval(sessionTimeWindowMinutes * 60)
    }

    // Available presets: 5 min, 15 min, 30 min, 1 hour, 4 hours, 1 day
    static let presets: [(label: String, minutes: Int)] = [
        ("5 minutes", 5),
        ("15 minutes", 15),
        ("30 minutes", 30),
        ("1 hour", 60),
        ("4 hours", 240),
        ("1 day", 1440)
    ]
}
