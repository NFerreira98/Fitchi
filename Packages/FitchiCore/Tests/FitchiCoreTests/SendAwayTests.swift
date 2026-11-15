import Foundation
import Testing

@testable import FitchiCore

@Suite("Developer tools: sending a pet away survives the sync")
struct SendAwayTests {
    let start = TestSupport.date()
    let context = TestSupport.context()

    @Test func aPetSentAwayStaysAwayWhenTheOtherDeviceSyncs() throws {
        // The watch fed the pet an hour ago; the phone then sends it away.
        var watchCopy = TestSupport.pet(at: start)
        var inventory = Inventory(consumables: ["kibble": 1])
        let kibble = try #require(TestSupport.catalog.item(id: "kibble"))
        let dog = try #require(TestSupport.catalog.species(id: "dog"))
        try Care.use(kibble, on: &watchCopy, species: dog, inventory: &inventory, at: start + .hour, in: context)
        let now = start + 2 * .hour
        let phoneCopy = watchCopy.leftAlone(until: now, in: context)
        #expect(phoneCopy.condition(at: now, in: context) == .ranAway)
        // Whichever way round they merge, it has run away on both.
        for merged in [phoneCopy.mergingNeeds(from: watchCopy), watchCopy.mergingNeeds(from: phoneCopy)] {
            #expect(merged.condition(at: now, in: context) == .ranAway)
            #expect(merged.ranAwayDate(at: now, in: context).map { abs($0.timeIntervalSince(now)) < 120 } == true)
        }
    }

    @Test func bringingItHomeEndsIt() throws {
        let now = start + .hour
        var pet = TestSupport.pet(at: start).leftAlone(until: now, in: context)
        let walk = TestSupport.sample("w", .walk, start: now, minutes: 70)
        try ComebackQuest.v1.bringHome(&pet, samples: [walk], at: now + 2 * .hour, in: context)
        #expect(pet.condition(at: now + 2 * .hour, in: context) != .ranAway)
        #expect(pet.condition(at: now + 3 * .hour, in: context) != .ranAway)
    }
}
