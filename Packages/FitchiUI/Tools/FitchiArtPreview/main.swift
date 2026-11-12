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
            LifeRows(catalog: catalog)
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
    var effects = PetEffects.none
    var caption: String?

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                SceneBackdrop(backdrop)
                PetFigure(speciesID: species, palette: palette, pose: pose, effects: effects)
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

/// Moods, wandering, naps and care moments, sampled from `PetLife` at telling moments.
struct LifeRows: View {
    let catalog: Catalog
    let seed = 4242

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                tile("cat", search(.content) { abs($0.pose.tilt) > 3 && $0.pose.flipped }, "Walking right")
                tile("dog", search(.content) { $0.pose.sleep >= 1 }, "Catnap")
                tile("axolotl", frame(PetMood(isHungry: true), at: 1), "Hungry")
                tile("cat", frame(PetMood(isDirty: true), at: 1), "Needs a bath")
                tile("dog", frame(PetMood(condition: .sad, isBored: true), at: 1), "Sad + bored")
                tile("axolotl", frame(PetMood(condition: .sick, isTired: true), at: 3), "Sick, sleepy")
            }
            HStack(spacing: 10) {
                tile("dog", frame(PetMood(isAsleep: true), at: 1.2), "Asleep at night")
                tile(
                    "cat", search(.init(condition: .thriving)) { $0.effects.hearts.map { $0 > 0.3 } ?? false },
                    "Thriving")
                tile("dog", care(.feed, at: 1.2), "Feed")
                tile("cat", care(.play, at: 1.0), "Play")
                tile("axolotl", care(.wash, at: 1.2), "Wash")
                tile("axolotl", care(.rest, at: 2), "Nap")
            }
        }
    }

    private func frame(_ mood: PetMood, at time: Double) -> PetFrame {
        PetLife.frame(at: time, seed: seed, mood: mood, wander: false)
    }

    private func care(_ action: CareAction, at elapsed: Double) -> PetFrame {
        PetLife.frame(
            at: 100 + elapsed, seed: seed, mood: .content,
            reaction: PetLife.Reaction(action: action, startedAt: 100), wander: false)
    }

    /// The first moment (in tenths of a second) that matches.
    private func search(_ mood: PetMood, where matches: (PetFrame) -> Bool) -> PetFrame {
        for tenth in 0..<20_000 {
            let frame = PetLife.frame(at: Double(tenth) / 10, seed: seed, mood: mood)
            if matches(frame) { return frame }
        }
        return PetFrame()
    }

    private func tile(_ species: String, _ frame: PetFrame, _ caption: String) -> some View {
        let palette =
            catalog.species(id: species).map { PetPalette.all(for: $0)[0] }
            ?? PetPalette.all(for: catalog.species[0])[0]
        return Tile(
            species: species, palette: palette, backdrop: .meadow, pose: frame.pose, effects: frame.effects,
            caption: caption)
    }
}

try ArtPreview.run()
