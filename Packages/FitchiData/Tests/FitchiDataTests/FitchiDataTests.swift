import Testing
@testable import FitchiData

@Suite("FitchiData")
struct FitchiDataTests {
    @Test func moduleLinks() {
        _ = FitchiData.self
    }
}
