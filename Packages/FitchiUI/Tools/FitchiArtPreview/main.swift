import FitchiCore
import FitchiUI
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Renders every species × palette (plus backdrops and a few poses) into one PNG for art review.
@MainActor
enum ArtPreview {
    static func run() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let output = arguments.first ?? "pets.png"
        let content = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "../../Content")
        let catalog = try Catalog.load(from: content)
        let renderer = ImageRenderer(content: ContactSheet(catalog: catalog))
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw PreviewError.renderFailed }
        let url = URL(fileURLWithPath: output) as CFURL
        guard let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
            throw PreviewError.writeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw PreviewError.writeFailed }
        print("Wrote \(output)")
    }

    enum PreviewError: Error { case renderFailed, writeFailed }
}

struct ContactSheet: View {
    let catalog: Catalog

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(["axolotl", "cat", "dog"], id: \.self) { species in
                HStack(spacing: 10) {
                    ForEach(palettes(species)) { palette in
                        Tile(species: species, palette: palette, backdrop: .meadow)
                    }
                }
            }
            HStack(spacing: 10) {
                Tile(species: "axolotl", palette: palettes("axolotl")[0], backdrop: .pond, caption: "Pond")
                Tile(species: "axolotl", palette: palettes("axolotl")[4], backdrop: .pond, caption: "Shiny at the pond")
                Tile(species: "cat", palette: palettes("cat")[0], backdrop: .pond, pose: happy, caption: "Happy")
                Tile(
                    species: "dog", palette: palettes("dog")[0], backdrop: .meadow, pose: munching, caption: "Munching")
                Tile(species: "axolotl", palette: palettes("axolotl")[0], backdrop: .meadow, pose: hop, caption: "Hop")
            }
        }
        .padding(20)
        .background(Color(white: 0.12))
    }

    private func palettes(_ speciesID: String) -> [PetPalette] {
        catalog.species(id: speciesID).map { PetPalette.all(for: $0) } ?? []
    }

    private var happy: PetPose {
        var pose = PetPose()
        pose.eyesOpen = 0
        pose.tailAngle = -12
        return pose
    }

    private var munching: PetPose {
        var pose = PetPose()
        pose.mouthOpen = 1
        pose.squash = 0.08
        pose.lookY = 1
        return pose
    }

    private var hop: PetPose {
        var pose = PetPose()
        pose.lift = 10
        pose.squash = -0.1
        pose.earAngle = 14
        pose.lookX = 0.8
        return pose
    }
}

struct Tile: View {
    let species: String
    let palette: PetPalette
    let backdrop: SceneBackdrop.Kind
    var pose = PetPose()
    var caption: String?

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                SceneBackdrop(backdrop)
                PetFigure(speciesID: species, palette: palette, pose: pose)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 6)
            }
            .frame(width: 180, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            Text(caption ?? palette.name)
                .font(.system(size: 14, weight: palette.isShiny ? .bold : .medium, design: .rounded))
                .foregroundStyle(palette.isShiny ? Color.yellow : Color.white)
        }
    }
}

try ArtPreview.run()
