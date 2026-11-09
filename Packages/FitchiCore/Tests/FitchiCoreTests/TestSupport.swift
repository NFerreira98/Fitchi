import Foundation
@testable import FitchiCore

enum TestSupport {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// A date in UTC. Defaults to noon so tests start outside night hours.
    static func date(
        _ year: Int = 2026, _ month: Int = 1, _ day: Int = 5, hour: Int = 12, minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    /// No night slowdown, so decay is linear and easy to reason about.
    static let flatConfig: DecayConfig = {
        var config = DecayConfig.v1
        config.nightFactor = 1
        return config
    }()

    static func context(_ config: DecayConfig = flatConfig, vacations: [DateInterval] = []) -> DecayContext {
        DecayContext(config: config, calendar: calendar, vacations: vacations)
    }

    /// Traits of 0.5 everywhere → every trait multiplier is exactly 1.0.
    static let averageTraits = PetTraits(appetite: 0.5, playfulness: 0.5, stamina: 0.5, tidiness: 0.5)

    static func pet(
        personality: Personality = .pickyEater,
        at date: Date = date(),
        active: Bool = true,
        initialValue: Double = 100
    ) -> Pet {
        var pet = Pet(
            name: "Mochi",
            speciesID: "dog",
            traits: averageTraits,
            personality: personality,
            hatchedAt: date,
            initialValue: initialValue
        )
        pet.setActive(active, at: date, in: context())
        return pet
    }

    static let catalog: Catalog = {
        let contentDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // FitchiCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // FitchiCore
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Content")
        do {
            return try Catalog.load(from: contentDirectory)
        } catch {
            fatalError("Could not load Content/ catalog: \(error)")
        }
    }()

    static func sample(
        _ id: String,
        _ kind: ActivityKind,
        start: Date,
        minutes: Double,
        effort: Effort? = nil,
        userEntered: Bool = false
    ) -> ActivitySample {
        ActivitySample(
            id: id,
            kind: kind,
            start: start,
            end: start.addingTimeInterval(minutes * 60),
            effort: effort,
            isUserEntered: userEntered
        )
    }
}
