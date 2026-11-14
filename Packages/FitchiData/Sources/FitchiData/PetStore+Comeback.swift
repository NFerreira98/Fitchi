import FitchiCore
import Foundation

/// Bringing a pet home after it ran away (`ComebackQuest`). Progress is derived from Health
/// data, like everything else, so it needs no saving; only the homecoming itself is saved, as
/// fresh stats on the pet, which wins any merge with the other device (newest need wins).
extension PetStore {
    public var comebackQuest: ComebackQuest { .v1 }

    /// How far the player is with bringing `pet` home, or nil if it hasn't run away.
    public func comebackProgress(
        for pet: Pet, samples: [ActivitySample], steps: [StepCount] = []
    ) -> ComebackProgress? {
        comebackQuest.progress(for: pet, samples: samples, steps: steps, at: clock.now, in: decay)
    }

    /// Welcomes the pet home once the quest is done. Returns false if it isn't done yet.
    @discardableResult
    public func bringHome(_ petID: UUID, samples: [ActivitySample], steps: [StepCount] = []) -> Bool {
        guard var pet = roster[petID] else { return false }
        let now = clock.now
        do {
            try comebackQuest.bringHome(&pet, samples: samples, steps: steps, at: now, in: decay)
        } catch {
            return false
        }
        try? roster.update(pet)
        try? repository?.save(pet, at: now)
        didChange()
        return true
    }

    /// Developer tool: the pet runs away right now, to try the comeback screen.
    public func sendAway(_ petID: UUID) {
        guard let pet = roster[petID] else { return }
        let now = clock.now
        let gone = pet.leftAlone(until: now, in: decay)
        try? roster.update(gone)
        try? repository?.save(gone, at: now)
        didChange()
    }
}
