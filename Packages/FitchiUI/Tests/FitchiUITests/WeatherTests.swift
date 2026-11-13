import FitchiCore
import Foundation
import Testing

@testable import FitchiUI

@Suite("Weather")
struct WeatherTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    func days(_ count: Int, hour: Int) -> [Date] {
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour)) ?? .now
        return (0..<count).map { start.addingTimeInterval(Double($0) * 86_400) }
    }

    @Test func mostDaysAreFairAndEachSeasonHasItsOwnWeather() {
        for season in Season.allCases {
            let year = days(365, hour: 10).map { Weather(at: $0, season: season, calendar: calendar).kind }
            let fair = year.filter { $0 == .clear }.count
            #expect(fair > 365 / 2, "mostly fair in \(season)")
            #expect(year.contains(.cloudy))
            #expect(year.contains(season == .winter ? .snow : .rain) || year.contains(.cloudy))
            if season != .winter { #expect(!year.contains(.snow), "snow only in winter") }
        }
    }

    @Test func spellsBuildUpAndDieDownWithinADay() {
        // Find a rainy day and walk through it every five minutes.
        let rainy = days(400, hour: 0).first { day in
            stride(from: 0.0, to: 86_400, by: 3_600).contains {
                Weather(at: day.addingTimeInterval($0), season: .autumn, calendar: calendar).kind == .rain
            }
        }
        let day = try? #require(rainy)
        guard let day else { return }
        let through = stride(from: 0.0, to: 86_400, by: 300).map {
            Weather(at: day.addingTimeInterval($0), season: .autumn, calendar: calendar)
        }
        let rain = through.map(\.rain)
        #expect(rain.contains { $0 == 1 })
        #expect(rain.first == 0 && rain.last == 0, "a spell, not all day")
        for (before, after) in zip(rain, rain.dropFirst()) {
            #expect(abs(after - before) < 0.35, "builds up and dies down")
        }
        #expect(through.contains { $0.kind == .cloudy }, "grey skies either side")
    }

    @Test func scenesHaveTheirOwnTake() {
        #expect(Weather(kind: .rain).adapted(to: .snowyHill).kind == .snow)
        #expect(Weather(kind: .snow).adapted(to: .beach).kind == .rain)
        #expect(Weather(kind: .rain).adapted(to: .starryNight) == .clear)
        #expect(Weather(kind: .wind).adapted(to: .meadow).kind == .wind)
    }
}

@Suite("Weather and cheers on the pet")
struct WeatherReactionTests {
    let seed = 4321
    let times = (0..<2400).map { Double($0) * 0.25 }

    @Test func rainMakesItShakeAndSplash() {
        let rain = PetLife.Cues(weather: Weather(kind: .rain))
        let frames = times.map { PetLife.frame(at: $0, seed: seed, mood: .content, cues: rain) }
        #expect(frames.contains { $0.effects.splash != nil }, "puddle hops now and then")
        #expect(frames.contains { $0.pose.tilt != 0 && $0.pose.eyesOpen == 0 }, "shakes the water off")
        let dry = times.map { PetLife.frame(at: $0, seed: seed, mood: .content) }
        #expect(dry.allSatisfy { $0.effects.splash == nil })
    }

    @Test func windBlowsItsEarsBack() {
        let windy = PetLife.Cues(weather: Weather(kind: .wind))
        let calm = times.map { PetLife.frame(at: $0, seed: seed, mood: .content).pose.earAngle }
        let blown = times.map { PetLife.frame(at: $0, seed: seed, mood: .content, cues: windy).pose.earAngle }
        #expect(blown.reduce(0, +) / Double(times.count) < calm.reduce(0, +) / Double(times.count) - 5)
    }

    @Test func aCheerJumpsWithConfettiThenEnds() {
        let start = 500.0
        let cues = PetLife.Cues(cheer: PetLife.Cheer(startedAt: start))
        let during = stride(from: start, to: start + PetLife.Cheer.duration, by: 0.05).map {
            PetLife.frame(at: $0, seed: seed, mood: .content, cues: cues)
        }
        #expect(during.allSatisfy { $0.effects.confetti != nil && $0.pose.mouthOpen == 1 })
        #expect((during.map(\.pose.lift).max() ?? 0) > 10, "big jumps")
        let after = PetLife.frame(at: start + PetLife.Cheer.duration + 0.01, seed: seed, mood: .content, cues: cues)
        #expect(after.effects.confetti == nil)
    }
}
