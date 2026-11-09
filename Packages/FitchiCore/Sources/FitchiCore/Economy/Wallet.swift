import Foundation

/// A non-activity change to the Pep balance. Append-only; ids make it safe to sync and merge.
public struct PepTransaction: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: Codable, Hashable, Sendable {
        case purchase(itemID: String)
        case welcomeBonus
        case achievementReward(achievementID: String)
        case adjustment(reason: String)
    }

    public var id: String
    public var kind: Kind
    /// Positive adds Pep, negative spends it.
    public var amount: Int
    public var date: Date

    public init(id: String, kind: Kind, amount: Int, date: Date) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.date = date
    }

    public static func purchase(itemID: String, price: Int, at date: Date, id: UUID = UUID()) -> PepTransaction {
        PepTransaction(id: "purchase:\(id.uuidString)", kind: .purchase(itemID: itemID), amount: -price, date: date)
    }

    /// Fixed id, so the bonus can only ever be granted once.
    public static func welcomeBonus(_ amount: Int, at date: Date) -> PepTransaction {
        PepTransaction(id: "welcome-bonus", kind: .welcomeBonus, amount: amount, date: date)
    }

    /// Fixed id per achievement, so each reward can only be granted once.
    public static func achievementReward(_ achievement: Achievement, at date: Date) -> PepTransaction {
        PepTransaction(
            id: "achievement:\(achievement.id)",
            kind: .achievementReward(achievementID: achievement.id),
            amount: achievement.reward,
            date: date
        )
    }
}

/// The player's Pep balance: Σ earnings + Σ transactions, de-duplicated by id.
public struct Wallet: Hashable, Sendable {
    public private(set) var earnings: [Earning]
    public private(set) var transactions: [PepTransaction]

    public init(earnings: [Earning] = [], transactions: [PepTransaction] = []) {
        self.earnings = Self.unique(earnings)
        self.transactions = Self.unique(transactions)
    }

    public var balance: Int {
        earnings.reduce(0) { $0 + $1.amount } + transactions.reduce(0) { $0 + $1.amount }
    }

    /// Lifetime Pep gained (activity, bonuses and rewards), ignoring spending.
    public var totalEarned: Int {
        earnings.reduce(0) { $0 + $1.amount } + transactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    public func canAfford(_ price: Int) -> Bool { balance >= price }

    public mutating func record(_ transaction: PepTransaction) {
        guard !transactions.contains(where: { $0.id == transaction.id }) else { return }
        transactions.append(transaction)
    }

    public mutating func replaceEarnings(_ earnings: [Earning]) {
        self.earnings = Self.unique(earnings)
    }

    private static func unique<T: Identifiable>(_ values: [T]) -> [T] {
        var seen = Set<T.ID>()
        return values.filter { seen.insert($0.id).inserted }
    }
}
