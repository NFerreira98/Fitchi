import FitchiCore
import FitchiData
import FitchiHealth
import FitchiUI
import Foundation
import UserNotifications
import WidgetKit

#if os(watchOS)
    import WatchKit
#else
    import UIKit
#endif

/// Everything outside the app that follows the pet: the watch-face complication or iPhone
/// widget, and care reminders. Refreshed after every change, at launch and whenever the app
/// comes forward. Shared by both apps (Apps/Shared).
@MainActor
enum PetCompanions {
    /// - Parameter sendsReminders: whether this device is the pet's home and sends care
    ///   reminders: always on the watch; on the iPhone only without a watch that has the app,
    ///   so nobody gets them twice. When false, any reminders planned earlier are cleared.
    static func refresh(_ pets: PetStore, sendsReminders: Bool = true) {
        GlanceStore.save(pets.glance)
        WidgetCenter.shared.reloadAllTimelines()
        let pet = sendsReminders ? pets.activePet : nil
        let decay = pets.decay
        let collected = pets.glance.collectedGifts ?? []
        let gifts = PetMoments.upcoming(after: .now, calendar: decay.calendar).filter { !collected.contains($0.id) }
        Task { await CareReminders.schedule(for: pet, gifts: gifts, in: decay) }
    }
}

/// Local notifications for the moments the pet will start needing something (see
/// `CareNudges`). Planned ahead from the decay model, so nothing has to run in the background;
/// any care re-plans them. Only the pet's home device schedules them (see `PetCompanions`).
enum CareReminders {
    /// `@AppStorage` key for the on/off switch in About.
    static let enabledKey = "fitchi.careReminders"
    static let idPrefix = "fitchi.nudge."
    static let giftPrefix = "fitchi.gift."
    /// watchOS keeps a limited number of pending notifications; a few ahead is plenty (and the
    /// same on the iPhone, where every change re-plans them anyway).
    static let maxPending = 6
    /// Of those, how many announce gifts (the rest are care nudges).
    static let maxGifts = 3

    /// While true (a hatch reveal is on screen), leave notifications alone so the permission
    /// prompt doesn't cover the reveal: planning waits until it's dismissed.
    @MainActor static var holdsPermissionPrompt = false

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    @MainActor
    static func schedule(for pet: Pet?, gifts: [PetMoment], in decay: DecayContext) async {
        guard !holdsPermissionPrompt else { return }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(idPrefix) || $0.hasPrefix(giftPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard isEnabled, let pet else { return }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }

        let now = Date()
        // Only while the pet is around to find things.
        let upcomingGifts = pet.mood(at: now, in: decay).condition.acceptsCare ? Array(gifts.prefix(maxGifts)) : []
        for gift in upcomingGifts {
            let content = UNMutableNotificationContent()
            content.title = "\(pet.name) found something! \(gift.isLucky ? "🪙" : "🎁")"
            content.body = "Come and see. It's waiting for the next 2 hours."
            content.sound = .default
            content.threadIdentifier = "fitchi.gifts"
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, gift.opens.timeIntervalSince(now)), repeats: false)
            try? await center.add(
                UNNotificationRequest(identifier: giftPrefix + gift.id, content: content, trigger: trigger))
        }
        let nudges = CareNudges.plan(for: pet, after: now, in: decay).prefix(maxPending - upcomingGifts.count)
        for (index, nudge) in nudges.enumerated() {
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

extension CareReminders {
    static var isInForeground: Bool {
        #if os(watchOS)
            WKApplication.shared().applicationState == .active
        #else
            UIApplication.shared.applicationState == .active
        #endif
    }

    /// A milestone reached while the app isn't on screen (HealthKit woke it in the background):
    /// a notification so the cheer isn't missed. The pet still celebrates when you next look.
    /// Shares the care-reminder switch, and never at night.
    @MainActor
    static func announceCheers(_ pets: PetStore, activity: ActivityStore) {
        guard !isInForeground, isEnabled, let pet = pets.activePet else { return }
        let hour = Calendar.current.component(.hour, from: .now)
        guard (7..<22).contains(hour) else { return }
        let reached = Cheers.reached(
            at: .now, samples: activity.samples, steps: activity.steps, today: activity.today,
            pepGoal: Int(activity.rules.dailySoftCap))
        let done = CheerLog.announced.ids.union(CheerLog.cheered.ids)
        guard let top = Cheers.next(in: reached, cheered: done) else { return }
        CheerLog.announced.mark(reached.map(\.id))
        let content = UNMutableNotificationContent()
        content.title = "\(pet.name) is cheering! 🎉"
        content.body = "\(top.headline) Come and celebrate."
        content.sound = .default
        content.threadIdentifier = "fitchi.cheers"
        let request = UNNotificationRequest(identifier: "fitchi.cheer.\(top.id)", content: content, trigger: nil)
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }
}
