import Foundation

/// What happened when an action ran, for feedback in the UI.
struct ActionOutcome: Equatable, Sendable {
    var action: PetAction
    var needChanges: [NeedKind: Double]
    var bondGained: Double
    /// The action was repeated inside its cooldown, so it did a little rather than a lot.
    var diminished: Bool
    var message: String
}

enum CareUrgency: Equatable, Sendable {
    case fine
    case low
    case urgent
}

/// The one thing the home screen suggests doing next.
struct CareSuggestion: Equatable, Sendable {
    var title: String
    var detail: String
    var action: PetAction?
    var need: NeedKind?
    var urgency: CareUrgency
}

/// Pure, time-based rules. Nothing here depends on timers: callers pass `now`, and the same
/// inputs always produce the same pet.
enum PetReducer {
    // MARK: Reconciliation

    /// Brings the pet up to `now`: needs decay for the elapsed time, naps restore energy and
    /// finish, long gaps are capped, and clocks that moved backwards are tolerated.
    static func reconcile(_ state: PetState, now: Date) -> PetState {
        var pet = state
        let elapsed = now.timeIntervalSince(pet.lastReconciledAt)

        guard elapsed > 0 else {
            return clampingTimestamps(of: pet, to: now)
        }

        let gap = min(elapsed, GameBalance.maxReconcileGap)
        let hours = gap / 3600
        let sleptSeconds = sleepingInterval(of: pet, from: now.addingTimeInterval(-gap), to: now)
        let sleptHours = sleptSeconds / 3600
        let awakeHours = max(0, hours - sleptHours)
        let wasNeedy = [NeedKind.fullness, .energy, .cleanliness].contains { pet.needs[$0] < GameBalance.lowNeed }

        for kind in NeedKind.allCases {
            let rate = GameBalance.decayPerHour[kind] ?? 0
            // Always assign through the subscript: it clamps to 0...100.
            switch kind {
            case .energy:
                pet.needs[.energy] += GameBalance.energyPerSleepingHour * sleptHours - rate * awakeHours
            case .mood:
                pet.needs[.mood] -= rate * hours + (wasNeedy ? GameBalance.moodPenaltyPerHourWhenNeedy * hours : 0)
            default:
                pet.needs[kind] -= rate * hours
            }
        }

        if gap >= 12 * 3600 {
            for kind in NeedKind.allCases {
                pet.needs[kind] = max(pet.needs[kind], GameBalance.offlineFloor)
            }
        }

        if let sleepingUntil = pet.sleepingUntil, sleepingUntil <= now {
            pet.sleepingUntil = nil
        }
        pet.lastReconciledAt = now
        return pet
    }

    /// Seconds within `start...end` that the pet spent napping.
    private static func sleepingInterval(of pet: PetState, from start: Date, to end: Date) -> TimeInterval {
        guard let sleepingUntil = pet.sleepingUntil else { return 0 }
        let sleepEnd = min(sleepingUntil, end)
        return max(0, sleepEnd.timeIntervalSince(start))
    }

    /// When the device clock jumps backwards, timestamps in the future would freeze cooldowns
    /// and naps; pull them back to `now` so the pet carries on normally.
    private static func clampingTimestamps(of state: PetState, to now: Date) -> PetState {
        var pet = state
        pet.lastReconciledAt = now
        if pet.adoptedAt > now { pet.adoptedAt = now }
        for action in PetAction.allCases where (pet.care[action] ?? .distantPast) > now {
            pet.care[action] = now
        }
        if let until = pet.sleepingUntil, until > now.addingTimeInterval(GameBalance.napDuration) {
            pet.sleepingUntil = now.addingTimeInterval(GameBalance.napDuration)
        }
        if let recent = pet.recentActivity, recent.at > now {
            pet.recentActivity = RecentActivity(action: recent.action, at: now)
        }
        return pet
    }

    // MARK: Actions

    static func apply(_ action: PetAction, to state: PetState, now: Date) -> (PetState, ActionOutcome) {
        var pet = reconcile(state, now: now)
        guard let effect = GameBalance.effects[action] else {
            preconditionFailure("No balance entry for \(action)")
        }

        let sinceLast = pet.care[action].map { now.timeIntervalSince($0) } ?? .infinity
        let diminished = sinceLast < effect.cooldown
        let multiplier = diminished ? GameBalance.diminishedMultiplier : 1
        let tired = pet.needs.energy < GameBalance.tiredEnergyThreshold

        var changes: [NeedKind: Double] = [:]
        for (kind, amount) in effect.needs {
            var scaled = amount * multiplier
            if action == .play, kind == .mood, tired { scaled *= 0.5 }
            let before = pet.needs[kind]
            pet.needs[kind] += scaled
            changes[kind] = pet.needs[kind] - before
        }

        let bondGained = diminished ? 0 : effect.bond
        pet.bond += bondGained
        pet.care[action] = now
        pet.recentActivity = RecentActivity(action: action, at: now)

        switch action {
        case .nap:
            pet.sleepingUntil = pet.isSleeping(at: now) ? nil : now.addingTimeInterval(GameBalance.napDuration)
        default:
            pet.sleepingUntil = nil
        }

        let outcome = ActionOutcome(
            action: action,
            needChanges: changes,
            bondGained: bondGained,
            diminished: diminished,
            message: message(for: action, pet: pet, diminished: diminished, wokeUp: action == .nap && pet.sleepingUntil == nil)
        )
        return (pet, outcome)
    }

    private static func message(for action: PetAction, pet: PetState, diminished: Bool, wokeUp: Bool) -> String {
        let name = pet.displayName
        let cat = pet.species == .cat
        switch (action, diminished) {
        case (.feed, false): return cat ? "\(name) crunches happily." : "\(name) wolfs it down."
        case (.feed, true): return "\(name) is still full — maybe later."
        case (.play, false): return cat ? "Pounce! \(name) is thrilled." : "Zoomies! \(name) is thrilled."
        case (.play, true): return "\(name) needs a breather first."
        case (.groom, false): return "Fluffed and shiny."
        case (.groom, true): return "\(name) is already spotless."
        case (.nap, _) where wokeUp: return "\(name) stretches awake."
        case (.nap, false): return "\(name) curls up for a nap."
        case (.nap, true): return "\(name) isn't sleepy yet, but settles down."
        case (.pet, false): return cat ? "\(name) purrs." : "\(name)'s tail goes wild."
        case (.pet, true): return "\(name) soaks up the love."
        }
    }

    // MARK: Derived state

    static func suggestion(for state: PetState, now: Date) -> CareSuggestion {
        let pet = reconcile(state, now: now)
        let name = pet.displayName

        if let until = pet.sleepingUntil, pet.isSleeping(at: now) {
            let minutes = max(1, Int(until.timeIntervalSince(now) / 60))
            return CareSuggestion(title: "Napping", detail: "\(name) wakes in about \(minutes) min. Any care wakes \(name) early.", action: nil, need: .energy, urgency: .fine)
        }

        let (kind, value) = pet.needs.lowest
        if value < GameBalance.urgentNeed {
            return CareSuggestion(title: urgentTitle(for: kind), detail: urgentDetail(for: kind, name: name), action: kind.remedy, need: kind, urgency: .urgent)
        }
        if value < GameBalance.lowNeed {
            return CareSuggestion(title: lowTitle(for: kind), detail: lowDetail(for: kind, name: name), action: kind.remedy, need: kind, urgency: .low)
        }
        return CareSuggestion(title: "All good", detail: "\(name) is content. Play or pet to grow your bond.", action: .play, need: nil, urgency: .fine)
    }

    static func needsAttention(_ state: PetState, now: Date) -> Bool {
        let pet = reconcile(state, now: now)
        return pet.needs.hasLowNeed && !pet.isSleeping(at: now)
    }

    /// Bond level from XP, with progress toward the next level.
    static func bondLevel(_ xp: Double) -> (level: Int, progress: Double) {
        var thresholds = GameBalance.bondLevels
        while thresholds.last! <= xp {
            thresholds.append(thresholds.last! + GameBalance.bondStep)
        }
        let level = thresholds.lastIndex { $0 <= xp } ?? 0
        let floor = thresholds[level]
        let ceiling = thresholds[level + 1]
        return (level + 1, (xp - floor) / (ceiling - floor))
    }

    /// Hours until the first need drops below the low threshold, or nil if one already has.
    static func hoursUntilNeedLow(_ state: PetState, now: Date) -> Double? {
        let pet = reconcile(state, now: now)
        var soonest = Double.infinity
        for kind in NeedKind.allCases {
            let value = pet.needs[kind]
            if value < GameBalance.lowNeed { return nil }
            guard let rate = GameBalance.decayPerHour[kind], rate > 0 else { continue }
            soonest = min(soonest, (value - GameBalance.lowNeed) / rate)
        }
        return soonest.isFinite ? soonest : nil
    }

    /// What the Live Activity should show, and for how long a timed action lasts.
    static func islandState(for state: PetState, now: Date) -> (state: IslandState, timed: ClosedRange<Date>?) {
        let pet = reconcile(state, now: now)
        if let until = pet.sleepingUntil, pet.isSleeping(at: now) {
            return (.sleeping, (until.addingTimeInterval(-GameBalance.napDuration))...until)
        }
        if let recent = pet.recentActivity {
            let shown: TimeInterval? = switch recent.action {
            case .feed: GameBalance.eatingShown
            case .play: GameBalance.playingShown
            case .pet, .groom: GameBalance.happyShown
            case .nap: nil
            }
            if let shown, now.timeIntervalSince(recent.at) < shown {
                let range = recent.at...recent.at.addingTimeInterval(shown)
                switch recent.action {
                case .feed: return (.eating, range)
                case .play: return (.playing, range)
                default: return (.happy, nil)
                }
            }
        }
        return (pet.needs.hasLowNeed ? .attention : .idle, nil)
    }

    static func caption(for state: PetState, now: Date) -> String {
        let pet = reconcile(state, now: now)
        let name = pet.displayName
        switch islandState(for: pet, now: now).state {
        case .sleeping: return pet.species == .cat ? "Curled up, dreaming of tuna" : "Snoring softly on the rug"
        case .eating: return pet.species == .cat ? "Crunching on a fish" : "Working on a bone"
        case .playing: return pet.species == .cat ? "Wrestling a ball of yarn" : "Chasing the tennis ball"
        case .happy: return pet.species == .cat ? "Purring like a tiny engine" : "Tail going a mile a minute"
        case .attention: return lowTitle(for: pet.needs.lowest.kind) + " — \(name) could use you"
        case .idle: return idleCaption(for: pet, hour: Calendar.current.component(.hour, from: now))
        }
    }

    // MARK: Copy

    private static func lowTitle(for kind: NeedKind) -> String {
        switch kind {
        case .fullness: "Getting hungry"
        case .energy: "Getting sleepy"
        case .cleanliness: "A bit scruffy"
        case .mood: "Feeling a little low"
        }
    }

    private static func urgentTitle(for kind: NeedKind) -> String {
        switch kind {
        case .fullness: "Very hungry"
        case .energy: "Exhausted"
        case .cleanliness: "Quite scruffy"
        case .mood: "Lonely"
        }
    }

    private static func lowDetail(for kind: NeedKind, name: String) -> String {
        switch kind {
        case .fullness: "A meal would hit the spot."
        case .energy: "\(name) could use a nap."
        case .cleanliness: "A quick groom would help."
        case .mood: "\(name) wants to play with you."
        }
    }

    private static func urgentDetail(for kind: NeedKind, name: String) -> String {
        switch kind {
        case .fullness: "\(name) has been waiting for a meal."
        case .energy: "Tuck \(name) in for a nap."
        case .cleanliness: "Time for a proper grooming."
        case .mood: "Some playtime would mean a lot to \(name)."
        }
    }

    private static func idleCaption(for pet: PetState, hour: Int) -> String {
        switch (hour, pet.species, pet.personality) {
        case (5..<11, .cat, _): "Stretching into the morning"
        case (5..<11, .dog, _): "Hoping for a morning walk"
        case (11..<17, .cat, .cozy): "Sunbathing on the island"
        case (11..<17, .cat, _): "Patrolling the island"
        case (11..<17, .dog, .bouncy): "Zooming around the island"
        case (11..<17, .dog, _): "Guarding the notch"
        case (17..<22, .cat, _): "Judging your screen time"
        case (17..<22, .dog, _): "Waiting for dinner"
        case (_, .cat, _): "Night watch, eyes half open"
        case (_, .dog, _): "Dozing by the door"
        }
    }
}
