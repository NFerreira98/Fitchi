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
        #expect(hungry.effects.thought == .feed)
        let dirty = PetLife.frame(at: 1, seed: seed, mood: PetMood(isDirty: true), wander: false)
        #expect(dirty.effects.stink && dirty.effects.smudges)
        let sad = PetLife.frame(at: 1, seed: seed, mood: PetMood(condition: .sad), wander: false)
        #expect(sad.pose.smile < 0 && sad.pose.worry > 0)
    }

    @Test(arguments: [CareAction.feed, .play, .wash, .rest])
    func careActsOutThenEnds(action: CareAction) {
        let reaction = PetLife.Reaction(action: action, startedAt: 500)
        let acting = 500 + PetLife.careApproach + 1.2
        let during = PetLife.frame(at: acting, seed: seed, mood: .content, reaction: reaction)
        switch action {
        case .rest: #expect(during.pose.sleep == 1)
        default: #expect(during.effects.prop != nil)
        }
        let after = PetLife.frame(at: reaction.endsAt + 0.1, seed: seed, mood: .content, reaction: reaction)
        #expect(after.effects.prop == nil)
    }

    @Test(arguments: [CareAction.feed, .play, .wash, .rest])
    func comesOverForCareAndWandersOffWithoutJumping(action: CareAction) {
        for start in stride(from: 300.0, to: 900, by: 37) {
            let reaction = PetLife.Reaction(action: action, startedAt: start)
            let frames = stride(from: start - 0.5, to: reaction.endsAt + 1, by: 0.05).map {
                PetLife.frame(at: $0, seed: seed, mood: .content, reaction: reaction)
            }
            let jumps = zip(frames, frames.dropFirst()).map { abs($1.x - $0.x) + abs($1.depth - $0.depth) }
            #expect((jumps.max() ?? 0) < 0.12, "no teleporting at \(start)")
            // Care happens near the front, where you are.
            let acting = PetLife.frame(
                at: start + PetLife.careApproach + 0.5, seed: seed, mood: .content, reaction: reaction)
            #expect(acting.depth > 0.8)
        }
    }

    @Test func caringChangesTheMoodButNotWhereThePetIs() {
        let moods = [PetMood.content, PetMood(isHungry: true), PetMood(isTired: true), PetMood(condition: .sad)]
        for time in stride(from: 0.0, to: 2_000, by: 3.3) {
            let places = Set(
                moods.map { mood in
                    let frame = PetLife.frame(at: time, seed: seed, mood: mood)
                    return [frame.x, frame.depth]
                })
            #expect(places.count == 1, "same spot whatever the mood at \(time)")
        }
    }

    @Test func aPetJustLookedAfterDoesNotDropIntoACatnap() throws {
        let tired = PetMood(isTired: true)
        // A moment deep in one of its catnaps.
        let napping = try #require(day.first { $0 > 200 && PetLife.napAmount(at: $0, seed: seed, mood: tired) >= 1 })
        let reaction = PetLife.Reaction(action: .feed, startedAt: napping - PetLife.duration(of: .feed) - 0.5)
        #expect(PetLife.frame(at: napping, seed: seed, mood: tired, reaction: reaction).pose.sleep == 0)
        #expect(PetLife.frame(at: napping, seed: seed, mood: tired).pose.sleep == 1)
    }

    @Test func atNightItStaysUpAWhileAfterCareThenDozesOff() {
        let night = PetMood(isAsleep: true)
        let reaction = PetLife.Reaction(action: .play, startedAt: 500)
        let awake = PetLife.frame(at: reaction.endsAt + 5, seed: seed, mood: night, reaction: reaction)
        #expect(awake.pose.sleep == 0)
        let later = PetLife.frame(
            at: reaction.endsAt + PetLife.nightLinger + 2, seed: seed, mood: night, reaction: reaction)
        #expect(later.pose.sleep == 1)
        // It comes back to its bed in the middle, where it was sleeping.
        #expect(
            abs(
                PetLife.frame(at: 499.9, seed: seed, mood: night).x
                    - PetLife.frame(at: 500, seed: seed, mood: night, reaction: reaction).x) < 0.01)
        #expect(abs(awake.x) < 0.01 && abs(awake.depth - 0.5) < 0.01)
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

    @Test func eachNeedHasItsOwnProp() {
        let hungry = (0..<40).map {
            PetLife.frame(at: Double($0) * 0.1, seed: seed, mood: PetMood(isHungry: true), wander: false)
        }
        #expect(hungry.contains { ($0.effects.rumble ?? 0) > 0.5 })
        let dirty = PetLife.frame(at: 1, seed: seed, mood: PetMood(isDirty: true), wander: false)
        #expect(dirty.effects.fly != nil)
        let sad = PetLife.frame(at: 1, seed: seed, mood: PetMood(condition: .sad), wander: false)
        #expect(sad.effects.raincloud != nil && sad.pose.earAngle < -5)
        let sick = PetLife.frame(at: 1, seed: seed, mood: PetMood(condition: .sick), wander: false)
        #expect(sick.effects.thermometer && sick.effects.queasy && !sick.effects.suitcase)
        let packing = PetLife.frame(at: 1, seed: seed, mood: PetMood(condition: .packing), wander: false)
        #expect(packing.effects.suitcase && packing.effects.thermometer)
        let asleep = PetLife.frame(at: 1, seed: seed, mood: PetMood(condition: .sad, isAsleep: true), wander: false)
        #expect(asleep.effects.raincloud == nil, "it sleeps it off")
    }

    @Test func fidgetsWhileStandingAboutAndKicksTheGroundWhenBored() {
        let times = stride(from: 0.0, to: 1_200, by: 0.2)
        let kinds = Set(times.compactMap { PetLife.fidget(at: $0, seed: seed, mood: .content)?.kind })
        #expect(kinds.count >= 6, "a good variety: \(kinds)")
        #expect(!kinds.contains(.scuff), "only a bored pet scuffs")
        let bored = times.map { PetLife.frame(at: $0, seed: seed, mood: PetMood(isBored: true)) }
        #expect(bored.contains { $0.effects.scuff != nil })
        // Fidgeting never moves the pet.
        for time in stride(from: 0.0, to: 300, by: 0.7)
        where PetLife.fidget(at: time, seed: seed, mood: .content) != nil {
            let frame = PetLife.frame(at: time, seed: seed, mood: .content)
            let place = PetLife.position(at: time, seed: seed)
            #expect(frame.x == place.x && frame.depth == place.depth)
        }
    }
}
