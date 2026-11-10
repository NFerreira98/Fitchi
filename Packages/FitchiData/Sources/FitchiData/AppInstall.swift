import Foundation

/// When Fitchi was first opened on this device. Activity before this earns nothing.
///
/// Stored in UserDefaults until the SwiftData + CloudKit store lands (Milestone 4), which will
/// keep the earliest install date across devices.
public enum AppInstall {
    static let key = "fitchi.installDate"

    /// Returns the saved install date, recording `now` the first time.
    public static func date(in defaults: UserDefaults = .standard, now: Date = Date()) -> Date {
        if let saved = defaults.object(forKey: key) as? Date { return saved }
        defaults.set(now, forKey: key)
        return now
    }
}
