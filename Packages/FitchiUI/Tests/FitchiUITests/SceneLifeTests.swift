import FitchiCore
import Foundation
import Testing

@testable import FitchiUI

@Suite("Scene light")
struct SceneLightTests {
    @Test func followsTheDay() {
        let noon = SceneLight(at: 12)
        #expect(noon.night == 0 && noon.warmth == 0)
        #expect(abs((noon.sun ?? 0) - 0.5) < 0.1, "high in the sky")
        let midnight = SceneLight(at: 0)
        #expect(midnight.night == 1 && midnight.sun == nil)
        #expect(SceneLight(at: 19.3).warmth > 0.9, "a sunset glow")
        #expect(SceneLight(at: 6.5).warmth > 0.9, "a sunrise glow")
        // Night falls gradually, never in one jump.
        let evening = stride(from: 18.0, through: 23, by: 0.1).map { SceneLight(at: $0).night }
        for (before, after) in zip(evening, evening.dropFirst()) {
            #expect(after >= before && after - before < 0.1)
        }
    }
}

@Suite("Visitors and greetings")
struct VisitorTests {
    let seed = 1234
    let day = (0..<4000).map { Double($0) * 0.25 }

    @Test func visitorsDropByNowAndThenAndThePetWatches() throws {
        let frames = day.map { PetLife.frame(at: $0, seed: seed, mood: .content, visitors: true) }
        let visits = frames.filter { $0.visitor != nil }
        #expect(!visits.isEmpty)
        #expect(Double(visits.count) < Double(day.count) * 0.3, "now and then, not all the time")
        for frame in visits {
            let visitor = try #require(frame.visitor)
            #expect(frame.pose.flipped == (visitor.offsetX > 0), "the pet turns to watch it")
            #expect(frame.pose.sleep == 0 && frame.pose.lookY < 0)
        }
        // Without visitors (indoors) or when the pet is down, nobody comes.
        #expect(day.allSatisfy { PetLife.frame(at: $0, seed: seed, mood: .content).visitor == nil })
        let sad = PetMood(condition: .sad)
        #expect(day.allSatisfy { PetLife.frame(at: $0, seed: seed, mood: sad, visitors: true).visitor == nil })
    }

    @Test func visitorsArriveAndLeaveOffStage() {
        for side in [-1.0, 1.0] {
            #expect(abs(PetLife.visitorPath(0, side: side).x) > 2)
            #expect(abs(PetLife.visitorPath(1, side: side).x) > 2)
            #expect(abs(PetLife.visitorPath(0.5, side: side).x) < 0.5, "loops around the pet's head")
            #expect(PetLife.visitorPath(0, side: side).x * PetLife.visitorPath(1, side: side).x < 0, "passes through")
        }
    }

    @Test func aBigHelloRunsToTheFrontAndWandersBackSmoothly() {
        // Find a moment the pet is awake and not napping.
        let start = day.first { PetLife.napAmount(at: $0, seed: seed, mood: .content) == 0 && $0 > 100 } ?? 100
        let greeting = PetLife.Greeting(startedAt: start, isBig: true)
        let before = PetLife.frame(at: start - 0.01, seed: seed, mood: .content)
        let first = PetLife.frame(at: start, seed: seed, mood: .content, greeting: greeting)
        #expect(abs(first.x - before.x) < 0.05 && abs(first.depth - before.depth) < 0.05)
        let middle = PetLife.frame(at: start + 2, seed: seed, mood: .content, greeting: greeting)
        #expect(middle.depth > 0.9 && abs(middle.x) < 0.01, "front and centre")
        let last = PetLife.frame(at: start + greeting.duration - 0.01, seed: seed, mood: .content, greeting: greeting)
        let after = PetLife.frame(at: start + greeting.duration, seed: seed, mood: .content, greeting: greeting)
        #expect(abs(last.x - after.x) < 0.05 && abs(last.depth - after.depth) < 0.05, "no jump at the end")
    }

    @Test func aSmallHelloFacesYouWithAGrin() {
        let greeting = PetLife.Greeting(startedAt: 0.5, isBig: false)
        let frame = PetLife.frame(at: 0.8, seed: seed, mood: .content, wander: false, greeting: greeting)
        #expect(frame.pose.lookX == 0 && frame.pose.mouthOpen > 0.5 && frame.pose.lift > 0)
        let asleep = PetLife.frame(at: 0.8, seed: seed, mood: PetMood(isAsleep: true), greeting: greeting)
        #expect(asleep.pose.sleep == 1, "a sleeping pet sleeps through it")
    }
}
