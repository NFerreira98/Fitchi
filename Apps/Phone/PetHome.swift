import FitchiData
import SwiftUI

/// Where the active pet lives, for the iPhone's wording: on the player's Apple Watch, or (with no
/// watch) right here on the iPhone, which is then the pet's home. Set at the root from
/// `BackupLink.watch`; until WatchConnectivity answers, assume a watch so nothing flickers for
/// watch owners.
enum PetHome: Equatable {
    case watch
    case phone

    init(_ watch: WatchPresence?) {
        self = watch.map { $0.isPaired ? .watch : .phone } ?? .watch
    }

    /// "Send to watch" / "Make active".
    var makeActive: String { self == .watch ? "Send to watch" : "Make active" }
    /// "On watch" / "Active".
    var activeShort: String { self == .watch ? "On watch" : "Active" }
    /// "Living on your watch" / "Your active pet".
    var activeLong: String { self == .watch ? "Living on your watch" : "Your active pet" }
    var symbol: String { self == .watch ? "applewatch" : "heart.fill" }
    /// For accessibility labels: "on your watch" / "active".
    var activeLabel: String { self == .watch ? "on your watch" : "active" }
}

extension EnvironmentValues {
    @Entry var petHome = PetHome.watch
}
