import FitchiCore
import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

/// The active pet on the iPhone, to play with just like on the watch: living in its scene, its
/// needs, the four care buttons (buying the item if needed) and the day's gift to collect.
/// Care from either device syncs and is all kept (each need merges on its own).
struct PhonePetView: View {
    @Environment(PetStore.self) private var pets
    @Environment(ActivityStore.self) private var activity
    @Environment(BackupLink.self) private var backup
    @Environment(\.petHome) private var home
    let pet: Pet
    /// The latest care tap or gift, driving the stage reaction, message and haptic.
    @State private var event: CareEvent?
    @State private var cheers = CheerBoard()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let mood = pet.mood(at: timeline.date, in: pets.decay)
            let afterglow = Afterglow.level(at: timeline.date, samples: activity.samples)
            let balance = pets.wallet(earnings: activity.earnings).balance
            VStack(spacing: FitchiTheme.Spacing.m) {
                PetStage(
                    pet: pet, species: pets.species(of: pet), mood: mood,
                    backdrop: SceneBackdrop.Kind(id: pets.inventory.activeBackdropID), style: .fullScene,
                    reaction: event?.reaction, petScale: 0.36, controlsBelow: false, afterglow: afterglow,
                    cheeredAt: cheers.current?.startedAt
                )
                .aspectRatio(1.1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 28))
                .overlay(alignment: .topTrailing) {
                    if let moment = pets.openMoment(at: timeline.date), event == nil {
                        giftButton(moment).padding(12)
                    }
                }
                .animation(.spring(duration: 0.4), value: pets.openMoment(at: timeline.date)?.id)
                header(balance: balance, status: status(mood: mood, afterglow: afterglow))
                StatBarsView(values: pet.values(at: timeline.date, in: pets.decay))
                    .padding(12)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 16))
                careButtons(balance: balance)
                if home == .watch {
                    Label(backupLine(at: timeline.date), systemImage: "arrow.triangle.2.circlepath")
                        .font(FitchiTheme.Fonts.text(.footnote))
                        .foregroundStyle(.secondary)
                }
                PetVoiceRow(voice: PetVoice(petID: pet.id, speciesID: pet.speciesID), petName: pet.name)
                    .padding(.horizontal, FitchiTheme.Spacing.m)
                    .padding(.vertical, FitchiTheme.Spacing.s)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 14))
            }
        }
        .sensoryFeedback(trigger: event) { _, new in new?.feedback }
        .sensoryFeedback(.success, trigger: cheers.current) { _, new in new != nil }
        .onChange(of: activity.lastRefreshed, initial: true) {
            cheers.check(
                at: .now, samples: activity.samples, steps: activity.steps, today: activity.today,
                pepGoal: Int(activity.rules.dailySoftCap))
        }
        .task(id: cheers.current) {
            guard cheers.current != nil else { return }
            try? await Task.sleep(for: CheerBoard.showsFor)
            cheers.finish()
        }
        .task(id: event) {
            guard event != nil else { return }
            // Long enough for the care animation (a nap is the longest) to finish.
            try? await Task.sleep(for: .seconds(4.2))
            event = nil
        }
    }

    private func status(mood: PetMood, afterglow: Double) -> String {
        event?.message ?? cheers.current?.milestone.message(petName: pet.name) ?? mood.headline(afterglow: afterglow)
    }

    private func header(balance: Int, status: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(pet.name).font(FitchiTheme.Fonts.display(.title))
                Spacer()
                Text("✦ \(balance) Pep")
                    .font(FitchiTheme.Fonts.display(.headline).monospacedDigit())
                    .foregroundStyle(FitchiTheme.Colors.points)
                    .contentTransition(.numericText(value: Double(balance)))
                    .animation(.snappy, value: balance)
            }
            Text(status)
                .font(FitchiTheme.Fonts.text(.subheadline, weight: .medium))
                .foregroundStyle(event == nil ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
                .animation(.easeInOut, value: status)
        }
    }

    // MARK: - Care and gifts

    private func careButtons(balance: Int) -> some View {
        HStack(spacing: FitchiTheme.Spacing.s) {
            ForEach([CareAction.feed, .play, .wash, .rest], id: \.self) { action in
                careButton(action, balance: balance)
            }
        }
    }

    private func careButton(_ action: CareAction, balance: Int) -> some View {
        let item = pets.careItem(action, for: pet, earnings: activity.earnings)
        let owned = item.map { pets.inventory.count(of: $0.id) } ?? 0
        let affordable = owned > 0 || (item?.price ?? .max) <= balance
        return Button {
            care(action)
        } label: {
            VStack(spacing: 2) {
                Text(action.emoji).font(.system(size: 26))
                Text(action.title).font(FitchiTheme.Fonts.display(.subheadline))
                Group {
                    if owned > 0 {
                        Text("×\(owned) owned").foregroundStyle(.secondary)
                    } else if let item {
                        Text("✦ \(item.price)").foregroundStyle(affordable ? FitchiTheme.Colors.points : .secondary)
                    } else {
                        Text(" ")
                    }
                }
                .font(FitchiTheme.Fonts.display(size: 12, weight: .semibold).monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.fill.tertiary, in: .rect(cornerRadius: 16))
            .opacity(affordable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(action.title)\(item.map { owned > 0 ? ", \(owned) owned" : ", \($0.price) Pep" } ?? "")")
    }

    private func care(_ action: CareAction) {
        do {
            let outcome = try pets.care(action, for: pet.id, earnings: activity.earnings)
            event = CareEvent(
                action: action, outcome: outcome, petName: pet.name,
                itemName: pets.catalog.item(id: outcome.itemID)?.name)
        } catch {
            event = CareEvent(action: action, failure: error, petName: pet.name)
        }
    }

    /// The pet found something: a bobbing present on the scene. Tap to collect it.
    private func giftButton(_ moment: PetMoment) -> some View {
        Button {
            if let collected = pets.collectGift() {
                event = CareEvent(gift: collected, petName: pet.name)
            }
        } label: {
            GiftBubble(isLucky: moment.isLucky).scaleEffect(1.3)
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
        .accessibilityHint("Collects what \(pet.name) found")
    }

    private func backupLine(at now: Date) -> String {
        guard let last = backup.lastExchange else { return "Shared with your watch" }
        let ago = last.formatted(.relative(presentation: .named, unitsStyle: .wide))
        return now.timeIntervalSince(last) < 60 ? "Synced with your watch just now" : "Synced with your watch \(ago)"
    }
}

/// The starter egg on an iPhone without a watch: a ring that fills as you move, then the hatch.
/// The reveal is shown by the parent, since this view goes away as soon as the pet exists.
struct PhoneEggView: View {
    @Environment(PetStore.self) private var pets
    @Environment(ActivityStore.self) private var activity
    let onHatch: (Pet) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            if let progress = pets.hatchProgress(samples: activity.samples, steps: activity.steps) {
                content(progress)
            }
        }
        #if targetEnvironment(simulator)
            // `xcrun simctl launch … -autoHatch YES` skips the walk, for screenshots and UI checks.
            .task {
                guard UserDefaults.standard.bool(forKey: "autoHatch") else { return }
                try? await Task.sleep(for: .seconds(1))
                hatch(force: true)
            }
        #endif
    }

    private func content(_ progress: HatchProgress) -> some View {
        VStack(spacing: FitchiTheme.Spacing.m) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress.fraction)
                    .stroke(FitchiTheme.Colors.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut, value: progress.fraction)
                EggFigure(crack: progress.isReady ? 1 : progress.fraction * 0.7)
                    .frame(width: 130, height: 130)
                    .phaseAnimator([-7.0, 7.0]) { egg, angle in
                        egg.rotationEffect(.degrees(angle), anchor: .bottom)
                    } animation: { _ in
                        .easeInOut(duration: progress.isReady ? 0.12 : 0.9)
                    }
            }
            .frame(width: 190, height: 190)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Egg, \(Int(progress.fraction * 100)) percent ready")

            if progress.isReady {
                Text("Something's moving!").font(FitchiTheme.Fonts.display(.title2))
                Button("Hatch!") { hatch(force: false) }
                    .font(FitchiTheme.Fonts.display(.headline))
                    .buttonStyle(.borderedProminent)
                    .tint(FitchiTheme.Colors.accent)
            } else {
                Text("Your egg").font(FitchiTheme.Fonts.display(.title2))
                Text("About \(progress.stepsRemaining) more steps to hatch")
                    .font(FitchiTheme.Fonts.display(.headline))
                let fallback = progress.fallbackDate.formatted(.dateTime.weekday(.wide).hour().minute())
                Text("Carry your iPhone as you walk: any steps count, a workout counts faster. Otherwise it hatches by \(fallback).")
                    .font(FitchiTheme.Fonts.text(.footnote))
                    .foregroundStyle(.secondary)
            }
            #if DEBUG
                Button("Hatch now (debug)") { hatch(force: true) }
                    .font(.caption)
            #endif
        }
        .multilineTextAlignment(.center)
        .padding(.top, FitchiTheme.Spacing.l)
    }

    private func hatch(force: Bool) {
        // The reveal comes first; the notification prompt can wait until it's dismissed.
        CareReminders.holdsPermissionPrompt = true
        if let pet = try? pets.hatchStarter(samples: activity.samples, steps: activity.steps, force: force) {
            onHatch(pet)
        }
    }
}
