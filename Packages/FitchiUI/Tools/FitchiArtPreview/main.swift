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
        var arguments = Array(CommandLine.arguments.dropFirst())
        // `--accessories` renders every species wearing every accessory instead.
        let accessories = arguments.first == "--accessories"
        if accessories { arguments.removeFirst() }
        // `--stages` renders live stages at phone and watch sizes, to check where pets stand.
        let stages = arguments.first == "--stages"
        if stages { arguments.removeFirst() }
        // `--scenes` renders every backdrop through the day, plus the visitors.
        let scenes = arguments.first == "--scenes"
        if scenes { arguments.removeFirst() }
        let output = arguments.first ?? "pets.png"
        let content = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "../../Content")
        let catalog = try Catalog.load(from: content)
        let renderer = ImageRenderer(
            content: Group {
                if scenes {
                    SceneSheet()
                } else if stages {
                    StageSheet(catalog: catalog)
                } else if accessories {
                    AccessorySheet(catalog: catalog)
                } else {
                    ContactSheet(catalog: catalog)
                }
            })
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
            ForEach(catalog.species.map(\.id).filter(PetFigure.hasArt(for:)), id: \.self) { species in
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
            // Every backdrop, each with a different pet standing in it.
            HStack(spacing: 10) {
                ForEach(Array(SceneBackdrop.Kind.allCases.enumerated()), id: \.offset) { index, kind in
                    let species = [
                        "axolotl", "cat", "dog", "bunny", "red-panda", "penguin", "platypus", "golden-axolotl", "cat",
                    ][index % 9]
                    Tile(
                        species: species, palette: palettes(species)[0], backdrop: kind,
                        caption: kind.rawValue.replacingOccurrences(of: "backdrop-", with: ""))
                }
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

/// Live stages (the phone card, then the three watch layouts) for several pets, each caught at a
/// different point of its wandering.
struct StageSheet: View {
    let catalog: Catalog
    let species = ["axolotl", "cat", "dog", "bunny", "penguin", "red-panda"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ForEach(Array(species.enumerated()), id: \.offset) { index, id in
                    stage(id, index, style: .fullScene, controlsBelow: false, scale: 0.36)
                        .frame(width: 330, height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
            ForEach([PetLayoutStyle.island, .fullScene, .horizon], id: \.self) { style in
                HStack(spacing: 12) {
                    ForEach(Array(species.enumerated()), id: \.offset) { index, id in
                        stage(id, index, style: style, controlsBelow: true, scale: style == .island ? 0.48 : 0.42)
                            .frame(width: 198, height: 242)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                    }
                }
            }
        }
        .padding(20)
        .background(Color(white: 0.12))
    }

    private func stage(
        _ id: String, _ index: Int, style: PetLayoutStyle, controlsBelow: Bool, scale: CGFloat
    ) -> some View {
        let pet = Pet(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index * 7 + 3)) ?? UUID(),
            name: id, speciesID: id, traits: PetTraits(appetite: 0.5, playfulness: 0.5, stamina: 0.5, tidiness: 0.5),
            personality: .easygoing, hatchedAt: .now)
        let backdrops: [SceneBackdrop.Kind] = [.meadow, .forest, .beach, .bedroom, .snowyHill, .livingRoom]
        return PetStage(
            pet: pet, species: catalog.species(id: id), backdrop: backdrops[index % backdrops.count], style: style,
            petScale: scale, controlsBelow: controlsBelow)
    }
}

/// Every backdrop at dawn, noon, dusk and midnight, mid-animation, and the three visitors.
struct SceneSheet: View {
    let times: [(String, SceneLight)] = [
        ("Dawn", .dawn), ("Noon", .day), ("Golden hour", SceneLight(at: 18.3)), ("Dusk", .dusk),
        ("Midnight", .midnight),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(SceneBackdrop.Kind.allCases, id: \.self) { kind in
                HStack(spacing: 10) {
                    ForEach(times, id: \.0) { name, light in
                        VStack(spacing: 4) {
                            SceneBackdrop(kind, time: 1_000, light: light)
                                .frame(width: 160, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                            Text("\(kind.rawValue.dropFirst(9)) · \(name)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            HStack(spacing: 20) {
                ForEach(Array([Visitor.Kind.butterfly, .bird, .firefly].enumerated()), id: \.offset) { index, kind in
                    ForEach(0..<3) { variety in
                        VisitorView(
                            kind: kind,
                            visitor: Visitor(
                                offsetX: 0, height: 1, facingRight: variety != 1, clock: Double(variety) * 0.07,
                                variety: variety)
                        )
                        .frame(width: 60, height: 60)
                        .background(index == 2 ? Color(white: 0.05) : Color(white: 0.85))
                    }
                }
            }
        }
        .padding(20)
        .background(Color(white: 0.12))
    }
}

/// One row per species: bare, then wearing each accessory, then a full outfit.
struct AccessorySheet: View {
    let catalog: Catalog

    var body: some View {
        let items = catalog.items.compactMap { item in item.slot.map { (item, $0) } }
        VStack(alignment: .leading, spacing: 18) {
            ForEach(catalog.species.map(\.id).filter(PetFigure.hasArt(for:)), id: \.self) { species in
                let palette =
                    catalog.species(id: species).map { PetPalette.all(for: $0)[0] }
                    ?? PetPalette.all(for: catalog.species[0])[0]
                HStack(spacing: 10) {
                    Tile(species: species, palette: palette, backdrop: .meadow, caption: species)
                    ForEach(items, id: \.0.id) { item, slot in
                        Tile(
                            species: species, palette: palette, backdrop: .meadow,
                            accessories: [slot: item.id], caption: item.name)
                    }
                    Tile(
                        species: species, palette: palette, backdrop: .bedroom, pose: walking,
                        accessories: [
                            .head: "party-hat", .face: "sunglasses", .neck: "red-bandana", .back: "hero-cape",
                        ],
                        caption: "Outfit, walking")
                }
            }
        }
        .padding(20)
        .background(Color(white: 0.12))
    }

    private var walking: PetPose {
        var pose = PetPose()
        pose.tilt = 6
        pose.flipped = true
        pose.lift = 3
        pose.headBob = 1.5
        return pose
    }
}

struct Tile: View {
    let species: String
    let palette: PetPalette
    let backdrop: SceneBackdrop.Kind
    var pose = PetPose()
    var effects = PetEffects.none
    var accessories: [AccessorySlot: String] = [:]
    var caption: String?

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                SceneBackdrop(backdrop)
                PetFigure(speciesID: species, palette: palette, pose: pose, effects: effects, accessories: accessories)
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
            HStack(spacing: 10) {
                // Faces differ per species (beaks, bills, teeth), so check moods on the newer ones.
                tile("penguin", frame(PetMood(isHungry: true), at: 1), "Hungry penguin")
                tile("platypus", care(.feed, at: 1.2), "Platypus eats")
                tile("red-panda", frame(PetMood(condition: .sad), at: 1), "Sad red panda")
                tile("bunny", frame(PetMood(isAsleep: true), at: 1.2), "Bunny asleep")
                tile(
                    "golden-axolotl",
                    search(.init(condition: .thriving)) { $0.effects.hearts.map { $0 > 0.3 } ?? false },
                    "Legendary, happy")
                tile("penguin", care(.wash, at: 1.4), "Penguin bath")
            }
            HStack(spacing: 10) {
                // Full lean both ways: tails and gills must not be cut off at the art square.
                tile("axolotl", leaning(6, flipped: false), "Lean left")
                tile("axolotl", leaning(-6, flipped: true), "Lean right")
                tile("cat", leaning(-6, flipped: true), "Cat lean")
                tile("dog", leaning(6, flipped: false), "Dog lean")
            }
        }
    }

    private func leaning(_ degrees: Double, flipped: Bool) -> PetFrame {
        var frame = PetFrame()
        frame.pose.tilt = degrees
        frame.pose.flipped = flipped
        frame.pose.lift = 2.4
        frame.pose.tailAngle = 10
        frame.pose.earAngle = 6
        return frame
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
