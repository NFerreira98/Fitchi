import Foundation

/// When Fitchi was first opened. Activity before this earns nothing.
///
/// Stored in UserDefaults. `BackupLink` shares it between watch and phone, and the earliest
/// wins, so reinstalling the watch app doesn't reset when Pep started counting.
public enum AppInstall {
    static let key = "fitchi.installDate"

    /// Returns the saved install date, recording `now` the first time.
    public static func date(in defaults: UserDefaults = .standard, now: Date = Date()) -> Date {
        if let saved = defaults.object(forKey: key) as? Date { return saved }
        defaults.set(now, forKey: key)
        return now
    }

    /// Adopts an earlier install date (from a backup). Returns true if it changed.
    @discardableResult
    public static func adopt(_ date: Date, in defaults: UserDefaults = .standard) -> Bool {
        if let saved = defaults.object(forKey: key) as? Date, saved <= date { return false }
        defaults.set(date, forKey: key)
        return true
    }
}
