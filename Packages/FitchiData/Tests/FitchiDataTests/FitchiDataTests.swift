import Foundation
import Testing
@testable import FitchiData

@Suite("FitchiData")
struct FitchiDataTests {
    @Test func installDateIsRecordedOnceAndThenKept() throws {
        let suite = "fitchi-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = Date(timeIntervalSince1970: 1_000_000)
        #expect(AppInstall.date(in: defaults, now: first) == first)
        #expect(AppInstall.date(in: defaults, now: first.addingTimeInterval(86_400)) == first)
    }
}
