import FitchiCore
import Foundation
import Testing

@testable import FitchiUI

@Suite("Accessory art")
struct AccessoryArtTests {
    static let content = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Content")

    @Test func everyAccessoryOnSaleHasADrawing() throws {
        let catalog = try Catalog.load(from: Self.content)
        let accessories = catalog.items.filter { $0.category == .accessory }
        #expect(!accessories.isEmpty)
        for item in accessories {
            #expect(AccessoryArt.drawn.contains(item.id), "\(item.id) is on sale but has no drawing")
        }
    }

    @Test func everyDrawnSpeciesHasAFit() throws {
        let catalog = try Catalog.load(from: Self.content)
        for species in catalog.species where PetFigure.hasArt(for: species.id) {
            #expect(PetFit.fits[species.id] != nil, "\(species.id) has no accessory fit")
        }
    }
}
