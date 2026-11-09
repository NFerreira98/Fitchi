# Fitchi — notes for Claude

Gamified fitness Tamagotchi: Apple Watch app + iPhone companion. See README.md for layout and roadmap.

## Commands
- `./scripts/bootstrap.sh` regenerates `Fitchi.xcodeproj` from `project.yml`. Run it after adding/removing files. Never edit the .xcodeproj directly.
- `./scripts/test.sh --packages` runs the fast package tests (`swift test`, no simulator).
- `./scripts/test.sh` runs the package tests and builds both apps for the simulator.
- `swiftlint lint --strict` must pass (CI enforces it). Formatting is owned by swift-format (`.swift-format`).

## Architecture rules
- **All game rules live in `Packages/FitchiCore`.** It must not import SwiftUI, HealthKit, SwiftData, UIKit or WatchKit. Anything time-dependent takes a `GameClock` (tests use `FixedClock`).
- **Pet stats are computed from timestamps** (`now − lastFedAt`), never decremented by timers or background tasks.
- **Points balance = Σ earned − Σ spent.** Earnings are derived from HealthKit samples, keyed by sample UUID (idempotent across watch and phone), and computed through a versioned `PointsRules`. Spending is an append-only ledger. Skip samples flagged `HKMetadataKeyWasUserEntered`.
- **Content is data:** shop items, pets and achievements come from JSON in `Content/`, not hard-coded Swift.
- **HealthKit** is imported only in `FitchiHealth`. **SwiftData** only in `FitchiData` and app targets.
- **SwiftData models must be CloudKit-compatible:** every property optional or defaulted, no `@Attribute(.unique)`, optional relationships. Dedupe in repositories.
- Swift 6 strict concurrency; `@Observable` view models; Swift Testing (`import Testing`) for tests.
- Randomness (hatching, trait rolls) takes `inout some RandomNumberGenerator`; tests use `SeededRandom`.
- Tests load the real `Content/` JSON, and `Catalog.validate()` must return no problems.

## Game design (tunable numbers live in `DecayConfig.v1`, `PointsRules.v1`, `ComebackQuest.v1`)
- Currency is **Pep**. "Treat" is a shop item, not the currency.
- Stats: hunger, happiness, energy, cleanliness, 0–100 where 100 = satisfied. Decay slows at night (22:00–07:00). Resting (non-active) pets decay at 25%.
- Pets never die. Neglect escalates sad → sick → packing → ranAway (after ~6 days of neglect, typically more than a week from full stats). A ran-away pet returns after a comeback quest (60 active minutes). Vacations pause both decay and the neglect clock.
- Pep = minutes × 1.2 × activity multiplier (run > walk) × effort bonus. Daily soft cap of 180, with half rate beyond it. Hand-entered and pre-install activity earns nothing. Welcome bonus 100.
- Pets come from eggs with rarity odds. The free starter is a random **common** species (dog, cat, axolotl). Each pet rolls its own traits within its species' range, plus a personality.
- Art styles are purchasable items (`category: artStyle`). Core only knows style ids; rendering picks the art.
- Bundle IDs: `com.nicholasferreira.fitchi` (phone), `.watchkitapp` (watch), `.watchkitapp.widgets` (complications).
