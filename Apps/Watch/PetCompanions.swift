import FitchiCore
import FitchiData
import FitchiUI
import Foundation
import UserNotifications
import WidgetKit

/// Everything outside the app that follows the pet: the watch-face complication and care
/// reminders. Refreshed after every change, at launch and whenever the app comes forward.
@MainActor
enum PetCompanions {
    static func refresh(_ pets: PetStore) {
        GlanceStore.save(pets.glance)
        WidgetCenter.shared.reloadAllTimelines()
        let pet = pets.activePet
        let decay = pets.decay
        Task { await CareReminders.schedule(for: pet, in: decay) }
    }
}

/// Local notifications for the moments the pet will start needing something (see
/// `CareNudges`). Planned ahead from the decay model, so nothing has to run in the background;
/// any care re-plans them. Only the watch schedules them, so the phone never doubles up.
enum CareReminders {
    /// `@AppStorage` key for the on/off switch in About.
    static let enabledKey = "fitchi.careReminders"
    static let idPrefix = "fitchi.nudge."
    /// watchOS keeps a limited number of pending notifications; a few ahead is plenty.
    static let maxPending = 6

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    @MainActor
    static func schedule(for pet: Pet?, in decay: DecayContext) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard isEnabled, let pet else { return }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }

        let now = Date()
        for (index, nudge) in CareNudges.plan(for: pet, after: now, in: decay).prefix(maxPending).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = title(for: nudge, name: pet.name)
            content.body = "Tap to check in on \(pet.name)."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, nudge.date.timeIntervalSince(now)), repeats: false)
            try? await center.add(
                UNNotificationRequest(identifier: "\(idPrefix)\(index)", content: content, trigger: trigger))
        }
    }

    /// "Maple is hungry 🍖", "Maple is hungry and grubby 🍖".
    static func title(for nudge: CareNudge, name: String) -> String {
        let words = nudge.stats.map(word(for:))
        let list: String
        switch words.count {
        case 0, 1: list = words.first ?? "missing you"
        case 2: list = "\(words[0]) and \(words[1])"
        default: list = words.dropLast().joined(separator: ", ") + " and " + (words.last ?? "")
        }
        let emoji = CareAction.allCases.first { $0.stat == nudge.stats.first }?.emoji ?? "💛"
        return "\(name) is \(list) \(emoji)"
    }

    static func word(for stat: Stat) -> String {
        switch stat {
        case .hunger: "hungry"
        case .happiness: "bored"
        case .energy: "sleepy"
        case .cleanliness: "grubby"
        }
    }
}
