import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsEdit = false
    @State private var showsSettings = false
    @State private var toast: ActionOutcome?
    @State private var toastTask: Task<Void, Never>?
    @AppStorage("islandpet.remindersPromptDismissed") private var remindersPromptDismissed = false

    private var store: PetStore { .shared }
    private var island: IslandVisitManager { .shared }
    private var services: AppServices { .shared }

    var body: some View {
        if let pet = store.pet {
            content(for: pet)
        }
    }

    private func content(for saved: PetState) -> some View {
        // Needs are time-based; re-derive them every minute so meters drift without a timer in the model.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let pet = PetReducer.reconcile(saved, now: now)
            let suggestion = PetReducer.suggestion(for: pet, now: now)
            NavigationStack {
                ScrollView {
                    VStack(spacing: 18) {
                        PetStageView(pet: pet, outcome: store.lastOutcome, now: now) {
                            perform(.pet)
                        }
                        PetHeader(pet: pet, now: now)
                        SuggestionCard(suggestion: suggestion) { action in
                            perform(action)
                        }
                        SectionCard(title: "Needs") {
                            VStack(spacing: 12) {
                                ForEach(NeedKind.allCases) { kind in
                                    NeedMeter(kind: kind, value: pet.needs[kind])
                                }
                            }
                        }
                        SectionCard(title: "Care") {
                            CareActionsGrid(pet: pet, now: now) { action in
                                perform(action)
                            }
                        }
                        if !remindersPromptDismissed && !ReminderScheduler.shared.settings.enabled {
                            ReminderPromptCard(name: pet.displayName) {
                                showsSettings = true
                                remindersPromptDismissed = true
                            } onDismiss: {
                                remindersPromptDismissed = true
                            }
                        }
                        IslandVisitCard(pet: pet)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(PastelBackground())
                .navigationTitle(pet.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showsSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showsEdit = true
                        } label: {
                            Label("Edit pet", systemImage: "pencil")
                        }
                    }
                }
                .sheet(isPresented: $showsEdit) {
                    EditPetSheet(pet: pet)
                }
                .sheet(isPresented: $showsSettings) {
                    SettingsSheet()
                }
                .overlay(alignment: .top) {
                    if let toast {
                        ToastView(outcome: toast)
                            .padding(.top, 8)
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.snappy, value: toast)
            }
        }
        .onChange(of: services.pendingRoute) { _, route in
            guard route != nil else { return }
            showsEdit = false
            showsSettings = false
            services.pendingRoute = nil
        }
    }

    private func perform(_ action: PetAction) {
        guard let outcome = store.perform(action) else { return }
        toast = outcome
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }
}

/// Name, stage, age and bond progress.
struct PetHeader: View {
    var pet: PetState
    var now: Date

    var body: some View {
        let stage = pet.growthStage(at: now)
        let days = Int(pet.ageDays(at: now))
        let bond = PetReducer.bondLevel(pet.bond)
        VStack(spacing: 8) {
            HStack {
                Label("\(stage.title) · \(days == 0 ? "adopted today" : "\(days) day\(days == 1 ? "" : "s") old")", systemImage: "leaf.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Pastel.muted)
                Spacer()
                Text("Bond Lv \(bond.level)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Pastel.ink)
            }
            ProgressView(value: bond.progress)
                .tint(Pastel.coral)
                .accessibilityLabel("Bond level \(bond.level)")
                .accessibilityValue("\(Int(bond.progress * 100)) percent to next level")
        }
        .padding(.horizontal, 4)
    }
}

struct SuggestionCard: View {
    var suggestion: CareSuggestion
    var onAction: (PetAction) -> Void

    private var tint: Color {
        switch suggestion.urgency {
        case .fine: Pastel.mint
        case .low: Pastel.butter
        case .urgent: Pastel.peach
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.need?.symbol ?? "checkmark.seal.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(suggestion.urgency == .fine ? Color(hex: 0x3E9C7A) : Pastel.warning)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Pastel.ink)
                Text(suggestion.detail)
                    .font(.footnote)
                    .foregroundStyle(Pastel.muted)
            }
            Spacer(minLength: 0)
            if let action = suggestion.action {
                Button(action.title) {
                    onAction(action)
                }
                .font(.subheadline.weight(.heavy))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(14)
        .background(tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Feed, Play, Groom, Nap with a note about when each last happened.
struct CareActionsGrid: View {
    var pet: PetState
    var now: Date
    var onAction: (PetAction) -> Void

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach([PetAction.feed, .play, .groom, .nap]) { action in
                Button {
                    onAction(action)
                } label: {
                    HStack(spacing: 10) {
                        PixelImage(image: PixelArt.prop(PetProp.prop(for: action, species: pet.species)))
                            .frame(width: 22, height: 22)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(Pastel.ink)
                            Text(lastDoneText(for: action))
                                .font(.caption2)
                                .foregroundStyle(Pastel.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 56)
                    .background(Pastel.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.title)
                .accessibilityHint(lastDoneText(for: action))
            }
        }
    }

    private func lastDoneText(for action: PetAction) -> String {
        guard let last = pet.care[action] else { return "Not yet" }
        let minutes = Int(now.timeIntervalSince(last) / 60)
        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr ago" }
        return "\(hours / 24) d ago"
    }
}

/// Shown once after adoption: what reminders do, with the choice to set them up or not.
struct ReminderPromptCard: View {
    var name: String
    var onSetUp: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        SectionCard(title: "Reminders") {
            Text("Want a gentle heads-up when \(name) is about to get hungry or sleepy? One notification at a time, never during quiet hours, and \(name) is fine without them.")
                .font(.footnote)
                .foregroundStyle(Pastel.muted)
            HStack(spacing: 10) {
                Button("Set up reminders", action: onSetUp)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                Button("Not now", action: onDismiss)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
            }
            .font(.subheadline.weight(.bold))
        }
    }
}

/// Starting, ending and renewing the pet's Dynamic Island visit.
struct IslandVisitCard: View {
    var pet: PetState
    @State private var isBusy = false

    private var island: IslandVisitManager { .shared }

    var body: some View {
        SectionCard(title: "Dynamic Island") {
            if !island.areActivitiesEnabled {
                Label("Live Activities are off for Island Pet. Turn them on in Settings to send \(pet.displayName) to the island.", systemImage: "bell.slash.fill")
                    .font(.footnote)
                    .foregroundStyle(Pastel.muted)
                if let settings = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: settings)
                        .font(.subheadline.weight(.bold))
                }
            } else if island.isVisiting, let endsAt = island.visitEndsAt {
                // A static string on purpose: a self-updating `Text(_:style:)` here put SwiftUI
                // into a layout loop that pinned the main thread. The surrounding TimelineView
                // refreshes this card every minute anyway.
                Label("On the island · ends \(endsAt.formatted(.relative(presentation: .numeric)))", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Pastel.ink)
                HStack(spacing: 10) {
                    Button("Renew visit") { run { await island.startVisit(for: pet) } }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    Button("End visit", role: .destructive) { run { await island.endVisit() } }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                }
                .font(.subheadline.weight(.bold))
                .disabled(isBusy)
            } else {
                Text("Visits last up to 8 hours, then \(pet.displayName) comes home. You can renew any time.")
                    .font(.footnote)
                    .foregroundStyle(Pastel.muted)
                Button {
                    run { await island.startVisit(for: pet) }
                } label: {
                    Label("Send \(pet.displayName) to the island", systemImage: "sparkles")
                        .font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .disabled(isBusy)
            }
            if let error = island.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func run(_ work: @escaping () async -> Void) {
        isBusy = true
        Task {
            await work()
            isBusy = false
        }
    }
}

#Preview {
    HomeView()
}
