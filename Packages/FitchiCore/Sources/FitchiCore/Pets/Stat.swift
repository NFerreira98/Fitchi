import Foundation

/// The four care needs every pet has. Each is a 0–100 value where **100 means fully satisfied**
/// (so a `hunger` of 100 is a full belly, 0 is starving).
public enum Stat: String, Codable, CaseIterable, Sendable, CodingKeyRepresentable {
    case hunger
    case happiness
    case energy
    case cleanliness

    public static let range: ClosedRange<Double> = 0...100
}

/// A stat's value at the last moment it was changed. Current values are computed by decaying
/// forward from the anchor, so nothing ever needs to "tick" in the background.
public struct StatAnchor: Codable, Hashable, Sendable {
    public var value: Double
    public var date: Date

    public init(value: Double, date: Date) {
        self.value = value
        self.date = date
    }
}
