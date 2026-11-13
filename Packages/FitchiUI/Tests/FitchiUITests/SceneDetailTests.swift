import FitchiCore
import Foundation
import Testing

@testable import FitchiUI

@Suite("Seasons")
struct SeasonTests {
    func date(month: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar.date(from: DateComponents(year: 2026, month: month, day: 15)) ?? .now
    }

    @Test func followTheCalendarAndFlipInTheSouth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let north: [Season] = (1...12).map { Season(at: date(month: $0), calendar: calendar, southern: false) }
        #expect(
            north == [
                .winter, .winter, .spring, .spring, .spring, .summer, .summer, .summer, .autumn, .autumn,
                .autumn, .winter,
            ])
        #expect(Season(at: date(month: 1), calendar: calendar, southern: true) == .summer)
        #expect(Season(at: date(month: 7), calendar: calendar, southern: true) == .winter)
        #expect(Season(at: date(month: 4), calendar: calendar, southern: true) == .autumn)
    }

    @Test func winterBringsBirdsSnowPrintsAndNoFireflies() {
        #expect(SceneBackdrop.Kind.meadow.visitor(in: .day, season: .winter) == .bird)
        #expect(SceneBackdrop.Kind.meadow.visitor(in: .midnight, season: .winter) == .bird)
        #expect(SceneBackdrop.Kind.meadow.visitor(in: .midnight, season: .summer) == .firefly)
        #expect(SceneBackdrop.Kind.beach.visitor(in: .day, season: .winter) == .butterfly, "the beach is always summer")
        #expect(SceneBackdrop.Kind.meadow.footing(in: .winter) == SceneBackdrop.Kind.snowyHill.footing(in: .summer))
        #expect(SceneBackdrop.Kind.kitchen.footing(in: .winter) == .none)
    }
}

@Suite("Footprints")
struct TrailTests {
    let seed = 1234

    @Test func strollsLeaveFootstepsThatFade() {
        let times = (400..<1600).map { Double($0) * 0.5 }
        let trails = times.map { PetLife.trail(at: $0, seed: seed, mood: .content, lasting: 6) }
        #expect(trails.contains { !$0.isEmpty }, "the pet walks somewhere")
        #expect(trails.contains { $0.isEmpty }, "and the prints fade away")
        for trail in trails {
            for step in trail {
                #expect(step.age >= 0 && step.age < 6)
                #expect(abs(step.x) <= 1 && (0...1).contains(step.depth))
            }
            // Left, right, left…
            for (one, next) in zip(trail, trail.dropFirst()) where abs(one.age - next.age - PetLife.stepEvery) < 0.01 {
                #expect(one.foot != next.foot)
            }
        }
        // Each step is where the pet was when it landed.
        for (time, trail) in zip(times, trails) {
            for step in trail {
                let place = PetLife.position(at: time - step.age, seed: seed, mood: .content)
                #expect(abs(place.x - step.x) < 0.001 && abs(place.depth - step.depth) < 0.001)
            }
        }
    }

    @Test func sleepingPetsLeaveNone() {
        let asleep = PetMood(isAsleep: true)
        #expect(
            (0..<200).allSatisfy { PetLife.trail(at: Double($0) * 3, seed: seed, mood: asleep, lasting: 6).isEmpty })
    }
}

@Suite("Personality habits")
struct HabitTests {
    let seed = 99
    let day = (0..<4000).map { Double($0) * 0.25 }

    @Test func petsShowTheirHabitsNowAndThen() {
        let playing = day.filter { PetLife.habit(at: $0, seed: seed, mood: .content) != nil }
        #expect(!playing.isEmpty)
        #expect(Double(playing.count) < Double(day.count) * 0.2, "now and then")
        for time in playing {
            let plain = PetLife.frame(at: time, seed: seed, mood: .content)
            for personality in Personality.allCases {
                let frame = PetLife.frame(at: time, seed: seed, mood: .content, personality: personality)
                #expect(frame.x == plain.x && frame.depth == plain.depth, "habits happen on the spot")
                #expect(frame.pose.sleep == 0)
            }
        }
        // Each personality looks different doing its thing.
        let middle = playing[playing.count / 2]
        let poses = Set(
            Personality.allCases.map { PetLife.frame(at: middle, seed: seed, mood: .content, personality: $0).pose })
        #expect(poses.count == Personality.allCases.count)
    }

    @Test func notWhenDownOrAsleep() {
        let sad = PetMood(condition: .sad)
        #expect(day.allSatisfy { PetLife.habit(at: $0, seed: seed, mood: sad) == nil })
        #expect(day.allSatisfy { PetLife.habit(at: $0, seed: seed, mood: PetMood(isAsleep: true)) == nil })
    }
}
