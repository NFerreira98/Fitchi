# Fitchi

A gamified fitness app for Apple Watch. Work out to earn points, then spend them to feed, dress up and care for your pet. Skip workouts and your pet gets hungry and bored.

Watch app + iPhone companion · SwiftUI · HealthKit · SwiftData + CloudKit · watchOS/iOS 26+

## Getting started

Requirements: macOS with **Xcode 26.4+** (selected via `xcode-select`), plus:

```sh
brew install xcodegen xcode-build-server swiftlint swift-format
./scripts/bootstrap.sh          # generates Fitchi.xcodeproj + VS Code language-server config
```

The `.xcodeproj` is **generated** from [`project.yml`](project.yml) and not committed. Re-run `./scripts/bootstrap.sh` after pulling or after adding/removing files.

To run on a real device, copy `Configs/Local.xcconfig.example` → `Configs/Local.xcconfig` and set your Apple Developer Team ID.

### Working in VS Code

Install the recommended extensions (**Swift**, **SweetPad**). Then:

- **Build / run:** SweetPad sidebar → pick the `FitchiWatch` or `FitchiPhone` scheme and a simulator → ▶.
- **Tests:** `Cmd+Shift+P` → *Tasks: Run Test Task* (runs package tests), or `./scripts/test.sh`.
- **Lint:** task *Fitchi: Lint* or `swiftlint lint`.

Open Xcode only for signing/capabilities, SwiftUI previews, Instruments and archiving.

### Updating your real iPhone / Apple Watch

```sh
./scripts/deploy.sh          # build + install on both
./scripts/deploy.sh phone    # iPhone only (fast)
./scripts/deploy.sh watch    # Apple Watch only
```

Or use the VS Code tasks *Fitchi: Deploy to …*. Keep the iPhone unlocked and the watch unlocked and awake. On a free Apple account, installs expire after 7 days, so just deploy again.

## Layout

| Path | What lives there |
|---|---|
| `Packages/FitchiCore` | Pure game rules: pet stats & decay, points, economy, achievements. No Apple app frameworks. |
| `Packages/FitchiData` | SwiftData models + repositories, CloudKit-synced. |
| `Packages/FitchiHealth` | HealthKit adapter (the only place that imports HealthKit). |
| `Packages/FitchiUI` | Shared SwiftUI components and design tokens. |
| `Apps/Watch` | watchOS app: home hub, quick actions, workouts. |
| `Apps/Phone` | iOS companion: onboarding, shop, wardrobe, achievements. |
| `Apps/Widgets` | Watch complications (WidgetKit). |
| `Content/` | JSON catalogs: `species.json`, `items.json`, `eggs.json`, `achievements.json`. |
| `Assets/` | Source art. |

## Roadmap

1. ✅ Foundation: project, packages, tooling, CI
2. ✅ Core game logic (`FitchiCore`, test-first)
3. 🚧 HealthKit integration (reading activity ✅; in-app workouts next)
4. Persistence & iCloud sync
5. Watch UI
6. Phone UI
7. Complications, notifications, multiple pets
8. Art pass, balancing, TestFlight
