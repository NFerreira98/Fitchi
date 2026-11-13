import FitchiCore
import Foundation
import Testing

@testable import FitchiUI

@Suite("Pet life")
struct PetLifeTests {
    let seed = 1234
    let day = (0..<3000).map { Double($0) * 0.4 }

    @Test func sameMomentAlwaysLooksTheSame() {
        for time in [3.0, 77.7, 1234.5] {
            #expect(
                PetLife.frame(at: time, seed: seed, mood: .content)
                    == PetLife.frame(at: time, seed: seed, mood: .content))
        }
    }

    @Test func wandersWithinItsPatchWithoutJumping() {
        let xs = day.map { PetLife.frame(at: $0, seed: seed, mood: .content).x }
        #expect(xs.allSatisfy { (-1...1).contains($0) })
        #expect(Set(xs.map { ($0 * 10).rounded() }).count > 5, "it actually moves around")
        // At walking speed it covers well under 0.3 of the patch in 0.4 s.
        for (before, after) in zip(xs, xs.dropFirst()) {
            #expect(abs(after - before) < 0.3)
        }
    }

    @Test func takesTheOddCatnapAndMoreWhenTired() {
        func napTime(_ mood: PetMood) -> Int {
            day.count { PetLife.frame(at: $0, seed: seed, mood: mood).pose.sleep >= 1 }
        }
        let rested = napTime(.content)
        let tired = napTime(PetMood(isTired: true))
        #expect(tired > rested)
        #expect(Double(rested) < Double(day.count) * 0.25)
    }

    @Test func sleepsAtNightWithZzzAndStaysPut() {
        let frames = day.prefix(200).map { PetLife.frame(at: $0, seed: seed, mood: PetMood(isAsleep: true)) }
        #expect(frames.allSatisfy { $0.pose.sleep == 1 && $0.effects.zzz && $0.x == 0 })
    }

    @Test func needsShowOnThePet() {
        let hungry = PetLife.frame(at: 1, seed: seed, mood: PetMood(isHungry: true), wander: false)
        #expect(hungry.effects.thought == CareAction.feed.emoji)
        let dirty = PetLife.frame(at: 1, seed: seed, mood: PetMood(isDirty: true), wander: false)
        #expect(dirty.effects.stink && dirty.effects.smudges)
        let sad = PetLife.frame(at: 1, seed: seed, mood: PetMood(condition: .sad), wander: false)
        #expect(sad.pose.smile < 0 && sad.pose.worry > 0)
    }

    @Test(arguments: [CareAction.feed, .play, .wash, .rest])
    func careActsOutThenEnds(action: CareAction) {
        let reaction = PetLife.Reaction(action: action, startedAt: 500)
        let during = PetLife.frame(at: 501.2, seed: seed, mood: .content, reaction: reaction)
        switch action {
        case .rest: #expect(during.pose.sleep == 1)
        default: #expect(during.effects.prop != nil)
        }
        // The pet holds still where it was standing while acting.
        let standing = PetLife.frame(at: 500, seed: seed, mood: .content, reaction: reaction).x
        #expect(during.x == standing)
        let after = PetLife.frame(at: 500 + reaction.duration + 0.1, seed: seed, mood: .content, reaction: reaction)
        #expect(after.effects.prop == nil)
    }

    @Test func reduceMotionKeepsThePetStill() {
        let frames = day.prefix(100).map { PetLife.frame(at: $0, seed: seed, mood: .content, still: true) }
        #expect(Set(frames).count == 1)
        #expect(frames.first?.x == 0)
    }

    @Test func strollsRoamFrontToBackAsWellAsSideToSide() {
        let frames = stride(from: 0.0, to: 3_600, by: 7).map {
            PetLife.frame(at: 800_000_000 + $0, seed: 42, mood: .content)
        }
        let depths = frames.map(\.depth)
        let xs = frames.map(\.x)
        #expect((depths.max() ?? 0) - (depths.min() ?? 0) > 0.7, "uses most of the ground's depth")
        #expect((xs.max() ?? 0) - (xs.min() ?? 0) > 1.2)
        #expect(depths.allSatisfy { (0...1).contains($0) })
    }

    @Test func depthChangesSmoothlyWhileWalking() {
        let frames = stride(from: 0.0, to: 600, by: 0.05).map {
            PetLife.frame(at: 800_000_000 + $0, seed: 7, mood: .content).depth
        }
        let biggestJump = zip(frames, frames.dropFirst()).map { abs($1 - $0) }.max() ?? 0
        #expect(biggestJump < 0.05, "no teleporting between spots")
    }
}
