import Foundation

/// The time of year. It dresses the green outdoor scenes and decides which special colourings
/// can hatch. A pure function of the date (and which half of the world you're in).
public enum Season: String, CaseIterable, Codable, Sendable {
    case spring, summer, autumn, winter

    /// Countries mostly or wholly south of the equator, where the seasons are the other way round.
    static let southernRegions: Set<String> = [
        "AR", "AU", "BO", "BR", "BW", "CL", "FJ", "LS", "MG", "MU", "MZ", "NA", "NC", "NZ", "PE", "PY", "SZ", "UY",
        "ZA", "ZW",
    ]

    /// - Parameter southern: nil works it out from the device's region.
    public init(at date: Date, calendar: Calendar = .current, southern: Bool? = nil) {
        let month = calendar.component(.month, from: date)
        let isSouthern = southern ?? Self.southernRegions.contains(Locale.current.region?.identifier ?? "")
        // Meteorological seasons: March–May is spring in the north.
        let north: [Season] = [.winter, .spring, .summer, .autumn]
        let index = (month % 12) / 3
        self = north[(index + (isSouthern ? 2 : 0)) % 4]
    }
}

/// Which part of the day it is, for things that only happen at certain times.
public enum TimeOfDay: String, CaseIterable, Codable, Sendable {
    /// 5:00–8:00
    case dawn
    /// 8:00–18:00
    case day
    /// 18:00–21:00
    case dusk
    /// 21:00–5:00
    case night

    public init(at date: Date, calendar: Calendar = .current) {
        switch calendar.component(.hour, from: date) {
        case 5..<8: self = .dawn
        case 8..<18: self = .day
        case 18..<21: self = .dusk
        default: self = .night
        }
    }
}
