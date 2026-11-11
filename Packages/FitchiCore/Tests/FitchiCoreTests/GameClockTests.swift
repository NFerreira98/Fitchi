import Foundation
import Testing

@testable import FitchiCore

@Suite("GameClock")
struct GameClockTests {
    @Test func fixedClockReturnsPinnedDate() {
        let date = Date(timeIntervalSince1970: 1_000)
        #expect(FixedClock(date).now == date)
    }

    @Test func fixedClockAdvances() {
        let clock = FixedClock(Date(timeIntervalSince1970: 0)).advanced(by: 3_600)
        #expect(clock.now.timeIntervalSince1970 == 3_600)
    }
}
