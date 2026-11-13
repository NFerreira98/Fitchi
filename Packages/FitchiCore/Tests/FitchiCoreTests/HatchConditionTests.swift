import Foundation
import Testing

@testable import FitchiCore

@Suite("Weather and time-of-day hatches")
struct HatchConditionTests {
    let catalog = TestSupport.catalog
    let now = TestSupport.date()
    let snowyNight = HatchMoment(season: .winter, weather: .snow, time: .night)
    let rainyDay = HatchMoment(season: .autumn, weather: .rain, time: .day)

    func hatches(_ eggID: String, at moment: HatchMoment, count: Int = 4_000, seed: UInt64 = 5) throws -> [Pet] {
        let egg = try #require(catalog.egg(id: eggID))
        var rng = SeededRandom(seed: seed)
        return try (0..<count).map { _ in
            try Hatchery.hatch(egg, from: catalog, at: now, moment: moment, using: &rng)
        }
    }

    func isSpecial(_ pet: Pet) -> Bool {
        guard let variant = pet.variant, !variant.isShiny else { return false }
        return catalog.species(id: pet.speciesID)?.variants.first { $0.id == variant.id }?.when != nil
    }

    func condition(_ pet: Pet) -> HatchCondition? {
        catalog.species(id: pet.speciesID)?.variants.first { $0.id == pet.variant?.id }?.when
    }

    @Test func everySpeciesHasTwoSpecialColourings() {
        for species in catalog.species {
            #expect(species.specialVariants.count == 2, "\(species.id)")
            let kinds = species.specialVariants.map { $0.when?.weather != nil }
            #expect(kinds.contains(true) && kinds.contains(false), "\(species.id): one weather, one time or season")
        }
        #expect(catalog.validate().isEmpty)
    }

    @Test func specialColouringsOnlyHatchInTheirMoment() throws {
        let plain = try hatches("meadow-egg", at: .plain) + hatches("sparkle-egg", at: .plain)
        #expect(!plain.contains(where: isSpecial), "nothing special on a fair summer's day")
        for moment in [snowyNight, rainyDay] {
            let pets = try hatches("meadow-egg", at: moment) + hatches("sparkle-egg", at: moment)
            let specials = pets.filter(isSpecial)
            #expect(!specials.isEmpty)
            for pet in specials {
                #expect(condition(pet)?.matches(moment) == true, "\(pet.variant?.id ?? "") at \(moment)")
            }
        }
    }

    @Test func rarityAndShinyOddsNeverChange() throws {
        func shares(_ pets: [Pet]) -> [Rarity: Double] {
            var counts: [Rarity: Double] = [:]
            for pet in pets { counts[catalog.species(id: pet.speciesID)?.rarity ?? .common, default: 0] += 1 }
            return counts.mapValues { $0 / Double(pets.count) }
        }
        let plain = try hatches("sparkle-egg", at: .plain, count: 8_000)
        let snowy = try hatches("sparkle-egg", at: snowyNight, count: 8_000)
        for rarity in Rarity.allCases {
            #expect(abs((shares(plain)[rarity] ?? 0) - (shares(snowy)[rarity] ?? 0)) < 0.025, "\(rarity)")
        }
        let shiny = Double(snowy.count(where: { $0.variant?.isShiny == true })) / Double(snowy.count)
        #expect(abs(shiny - 1.0 / 64) < 0.006)
    }

    @Test func affinitiesTiltWhichSpeciesWithinTheRarity() throws {
        func penguinShare(_ moment: HatchMoment) throws -> Double {
            let rares = try hatches("golden-egg", at: moment, count: 6_000).filter {
                catalog.species(id: $0.speciesID)?.rarity == .rare
            }
            return Double(rares.count { $0.speciesID == "penguin" }) / Double(rares.count)
        }
        // Even odds normally; in the snow penguins ×3 against red pandas ×2: 3 / 5.
        #expect(abs(try penguinShare(.plain) - 0.5) < 0.04)
        #expect(abs(try penguinShare(HatchMoment(season: .winter, weather: .snow, time: .day)) - 0.6) < 0.04)
        // Rainy days bring out the axolotls among the commons: 3 / (1 + 1 + 3).
        let commons = try hatches("meadow-egg", at: rainyDay).filter {
            catalog.species(id: $0.speciesID)?.rarity == .common
        }
        let axolotls = Double(commons.count { $0.speciesID == "axolotl" }) / Double(commons.count)
        #expect(abs(axolotls - 0.6) < 0.04)
    }

    @Test func theStarterCanBeSpecialToo() throws {
        var rng = SeededRandom(seed: 2)
        let night = HatchMoment(season: .summer, weather: .clear, time: .night)
        let starters = try (0..<2_000).map { _ in
            try Hatchery.hatchStarter(from: catalog, at: now, moment: night, using: &rng)
        }
        #expect(starters.contains { $0.variant?.id == "midnight" })
        #expect(!starters.contains { $0.variant?.id == "raindrop" }, "no rain tonight")
        let cats = Double(starters.count { $0.speciesID == "cat" }) / Double(starters.count)
        #expect(abs(cats - 0.5) < 0.05, "cats like the night: 2 / (1 + 2 + 1)")
    }

    @Test func momentsFollowTheClockAndTheWeather() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        func at(_ hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: hour)) ?? .now
        }
        #expect(HatchMoment(at: at(6), calendar: calendar, southern: false).time == .dawn)
        #expect(HatchMoment(at: at(12), calendar: calendar, southern: false).time == .day)
        #expect(HatchMoment(at: at(19), calendar: calendar, southern: false).time == .dusk)
        #expect(HatchMoment(at: at(23), calendar: calendar, southern: false).time == .night)
        #expect(HatchMoment(at: at(12), calendar: calendar, southern: false).season == .winter)
        #expect(HatchMoment(at: at(12), calendar: calendar, southern: true).season == .summer)
        // A spell only counts once it has properly started.
        #expect(Weather(kind: .rain, amount: 0.1).settledKind == .clear)
        #expect(Weather(kind: .rain, amount: 0.8).settledKind == .rain)
    }

    @Test func theCollectionShowsWhenSpecialsCanBeFound() {
        let book = CollectionBook(catalog: catalog, pets: [])
        #expect(book.specialsTotal == 16)
        let midnight = book.entries.first { $0.variantID == "midnight" }
        #expect(midnight?.condition == HatchCondition(time: .night))
    }

    @Test func badConditionsAreCaught() throws {
        var broken = catalog
        let index = try #require(broken.species.firstIndex { $0.id == "dog" })
        broken.species[index].variants[0].when = HatchCondition()
        broken.species[index].affinities.append(SpeciesAffinity(when: HatchCondition(weather: .rain), boost: 0))
        let problems = broken.validate()
        #expect(problems.contains { $0.contains("empty 'when'") })
        #expect(problems.contains { $0.contains("non-positive boost") })
    }
}
