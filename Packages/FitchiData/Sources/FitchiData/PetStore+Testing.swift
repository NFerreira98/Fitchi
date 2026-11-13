import FitchiCore
import Foundation

/// Developer tools for trying features out without walking for them. Test Pep is a ledger
/// adjustment like any other, so it syncs to the watch, and it can be taken back out.
extension PetStore {
    static let testPepPrefix = "test-pep:"

    /// Test Pep granted and not yet removed.
    public var testPep: Int {
        transactions.filter { $0.id.hasPrefix(Self.testPepPrefix) }.reduce(0) { $0 + $1.amount }
    }

    public func grantTestPep(_ amount: Int) {
        guard amount > 0 else { return }
        appendTestPep(amount)
    }

    /// Takes back test Pep, as much as the balance allows (Pep already spent stays spent).
    public func removeTestPep(earnings: [Earning]) {
        let amount = min(testPep, wallet(earnings: earnings).balance)
        guard amount > 0 else { return }
        appendTestPep(-amount)
    }

    private func appendTestPep(_ amount: Int) {
        let entry = PepTransaction(
            id: Self.testPepPrefix + UUID().uuidString, kind: .adjustment(reason: "Developer test Pep"),
            amount: amount, date: clock.now)
        try? repository?.append([entry])
        transactions.append(entry)
        didChange()
    }

    /// A streak-reward egg without the streak, for trying the free-egg hatch.
    public func grantTestRewardEgg(_ eggID: String) {
        let entry = PepTransaction(
            id: "\(DailyQuests.eggTokenPrefix)test-\(UUID().uuidString):\(eggID)",
            kind: .adjustment(reason: "Developer test egg"), amount: 0, date: clock.now)
        try? repository?.append([entry])
        transactions.append(entry)
        didChange()
    }
}
