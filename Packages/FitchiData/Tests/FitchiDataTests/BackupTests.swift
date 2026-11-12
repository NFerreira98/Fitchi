import FitchiCore
import Foundation
import SwiftData
import Testing

@testable import FitchiData

@Suite("Backup and restore")
@MainActor
struct BackupTests {
    let suite = PetStoreTests()
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    func pet(named name: String, hatchedAt: Date, active: Bool = true) -> Pet {
        Pet(
            name: name, speciesID: "dog",
            traits: PetTraits(appetite: 0.5, playfulness: 0.5, stamina: 0.5, tidiness: 0.5),
            personality: .easygoing, hatchedAt: hatchedAt, isActive: active)
    }

    @Test func mergeKeepsNewestPetsUnionsLedgerAndPrefersHatchedEgg() {
        var maple = pet(named: "Maple", hatchedAt: start)
        let old = GameSnapshot.SavedPet(pet: maple, updatedAt: start)
        maple.name = "Maple II"
        let renamed = GameSnapshot.SavedPet(pet: maple, updatedAt: start + 60)
        let hatched = StarterEgg(grantedAt: start - 3600, hatchedPetID: maple.id)
        let fresh = StarterEgg(grantedAt: start + 86_400)
        let bonus = PepTransaction.welcomeBonus(100, at: start)
        let snack = PepTransaction.purchase(itemID: "treat", price: 5, at: start + 10)

        let watch = GameSnapshot(pets: [old], starterEgg: fresh, transactions: [bonus], installDate: start + 86_400)
        let phone = GameSnapshot(
            pets: [renamed], starterEgg: hatched, transactions: [bonus, snack], installDate: start - 3600)
        let merged = watch.merged(with: phone)

        #expect(merged.pets.map(\.pet.name) == ["Maple II"])
        #expect(merged.starterEgg == hatched)
        #expect(Set(merged.transactions.map(\.id)) == [bonus.id, snack.id])
        #expect(merged.installDate == start - 3600)
        // Order and repetition don't matter.
        #expect(phone.merged(with: watch) == merged)
        #expect(merged.merged(with: watch) == merged)
    }

    @Test func snapshotSurvivesEncoding() throws {
        let snapshot = GameSnapshot(
            pets: [.init(pet: pet(named: "Maple", hatchedAt: start), updatedAt: start)],
            starterEgg: StarterEgg(grantedAt: start), transactions: [.welcomeBonus(100, at: start)], installDate: start)
        #expect(try GameSnapshot.decode(snapshot.encoded()) == snapshot)
    }

    @Test func reinstalledWatchGetsItsPetAndPepBack() throws {
        // The watch hatches a pet and spends some Pep; the phone keeps a backup.
        let watch = suite.makeStore(try FitchiStore.makeContainer(inMemory: true), at: start)
        let maple = try watch.hatchStarter(samples: [], force: true)
        watch.rename(maple.id, to: "Maple")
        let later = start + 12 * 3600
        let watchLater = PetStore(
            repository: GameRepository(container: try FitchiStore.makeContainer(inMemory: true)),
            catalog: suite.catalog,
            clock: FixedClock(later))
        watchLater.load()
        let backup = try #require(watch.snapshot(installDate: start))
        let phone = PetStore(
            repository: GameRepository(container: try FitchiStore.makeContainer(inMemory: true)),
            catalog: suite.catalog,
            clock: FixedClock(later))
        phone.load(grantsStarterEgg: false)
        #expect(phone.pendingEgg == nil)
        #expect(phone.restore(from: backup))
        #expect(phone.activePet?.name == "Maple")

        // Reinstalled: a fresh install with a brand-new egg, then the backup arrives.
        #expect(watchLater.pendingEgg != nil)
        #expect(watchLater.restore(from: try #require(phone.snapshot(installDate: start))))
        #expect(watchLater.activePet?.id == maple.id)
        #expect(watchLater.activePet?.name == "Maple")
        #expect(watchLater.pendingEgg == nil, "the old hatched egg wins, so no second egg")
        #expect(watchLater.transactions.count { $0.kind == .welcomeBonus } == 1)
        // Restoring the same backup again changes nothing.
        #expect(!watchLater.restore(from: backup))
    }

    @Test func petHatchedBeforeTheBackupArrivedIsKeptButResting() throws {
        let original = suite.makeStore(try FitchiStore.makeContainer(inMemory: true), at: start)
        let maple = try original.hatchStarter(samples: [], force: true)
        let backup = try #require(original.snapshot(installDate: start))

        let reinstalled = suite.makeStore(try FitchiStore.makeContainer(inMemory: true), at: start + 86_400)
        let newcomer = try reinstalled.hatchStarter(samples: [], force: true)
        var changes = 0
        reinstalled.onChange { changes += 1 }
        #expect(reinstalled.restore(from: backup))
        #expect(changes == 1)
        #expect(reinstalled.roster.pets.count == 2)
        #expect(reinstalled.activePet?.id == maple.id)
        #expect(reinstalled.roster[newcomer.id]?.isActive == false)
    }

    @Test func earlierInstallDateIsAdopted() throws {
        let defaults = try #require(UserDefaults(suiteName: "backup-tests-\(UUID().uuidString)"))
        #expect(AppInstall.date(in: defaults, now: start) == start)
        #expect(!AppInstall.adopt(start + 60, in: defaults))
        #expect(AppInstall.adopt(start - 60, in: defaults))
        #expect(AppInstall.date(in: defaults) == start - 60)
    }
}
