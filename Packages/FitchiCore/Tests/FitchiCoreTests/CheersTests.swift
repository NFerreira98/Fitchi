import Foundation
import Testing

@testable import FitchiCore

@Suite("Cheers")
struct CheersTests {
    let calendar = TestSupport.calendar
    func at(_ hour: Int, _ minute: Int = 0) -> Date { TestSupport.date(2026, 3, 9, hour: hour, minute: minute) }
    func hour(_ hour: Int, steps: Double) -> StepCount { StepCount(start: at(hour), end: at(hour + 1), steps: steps) }

    @Test func stepMarksAreReachedWhenTheyArePassed() {
        let steps = [hour(8, steps: 3_000), hour(9, steps: 2_500), hour(12, steps: 5_000)]
        let early = Cheers.reached(at: at(10), samples: [], steps: steps, calendar: calendar)
        #expect(early.map(\.id) == ["cheer:2026-03-09:steps-5000"])
        #expect(early.first?.happenedAt == at(10), "during the 9 o'clock hour")
        let later = Cheers.reached(at: at(13), samples: [], steps: steps, calendar: calendar)
        #expect(later.map(\.kind) == [.steps(5_000), .steps(10_000)])
        // Yesterday's steps don't count today.
        let tomorrow = TestSupport.date(2026, 3, 10, hour: 9)
        #expect(Cheers.reached(at: tomorrow, samples: [], steps: steps, calendar: calendar).isEmpty)
    }

    @Test func workoutsAndActiveMinutes() {
        let samples = [
            ActivitySample(id: "run", kind: .run, start: at(7), end: at(7, 35)),
            ActivitySample(id: "passive", kind: .passive, start: at(12), end: at(12, 20)),
            ActivitySample(id: "typed", kind: .run, start: at(13), end: at(14), isUserEntered: true),
            ActivitySample(id: "short", kind: .walk, start: at(15), end: at(15, 5)),
        ]
        let reached = Cheers.reached(at: at(16), samples: samples, steps: [], calendar: calendar)
        #expect(reached.contains { $0.id == "cheer:workout:run" && $0.kind == .workout(.run, minutes: 35) })
        #expect(!reached.contains { $0.id.contains("passive") || $0.id.contains("typed") || $0.id.contains("short") })
        // 35 + 20 + 5 active minutes (hand-entered ones don't count): past 30 and 60.
        #expect(reached.contains { $0.kind == .activeMinutes(30) && $0.happenedAt == at(7, 35) })
        #expect(reached.contains { $0.kind == .activeMinutes(60) && $0.happenedAt == at(15, 5) })
        #expect(!reached.contains { $0.kind == .activeMinutes(90) })
    }

    @Test func pepGoalAndPickingWhichToCheer() {
        let reached = Cheers.reached(
            at: at(18), samples: [ActivitySample(id: "run", kind: .run, start: at(7), end: at(7, 35))],
            steps: [hour(8, steps: 11_000)], pepGoal: 180, pepEarned: 190, calendar: calendar)
        #expect(reached.contains { $0.kind == .pepGoal(180) })
        // The workout matters most; once cheered, the Pep goal; then the biggest step mark.
        #expect(Cheers.next(in: reached, cheered: [])?.id == "cheer:workout:run")
        #expect(Cheers.next(in: reached, cheered: ["cheer:workout:run"])?.kind == .pepGoal(180))
        let rest = Cheers.next(in: reached, cheered: ["cheer:workout:run", "cheer:2026-03-09:pep-goal"])
        #expect(rest?.kind == .steps(10_000))
        #expect(Cheers.next(in: reached, cheered: Set(reached.map(\.id))) == nil, "each cheers once")
    }
}
