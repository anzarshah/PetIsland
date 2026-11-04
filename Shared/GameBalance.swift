import Foundation

/// Every tunable number in the game, in one place.
enum GameBalance {
    // MARK: Needs (0...100)

    static let needMax = 100.0
    /// Below this a need counts as low: it drives the "needs now" suggestion, the island's
    /// attention state, and care reminders.
    static let lowNeed = 35.0
    /// Below this the need is urgent and the suggestion wording gets a little firmer.
    static let urgentNeed = 15.0

    /// Points lost per hour while awake.
    static let decayPerHour: [NeedKind: Double] = [
        .fullness: 4.0,
        .energy: 3.0,
        .cleanliness: 2.0,
        .mood: 2.0,
    ]
    /// Extra mood loss per hour while any other need is low: a hungry pet gets grumpy.
    static let moodPenaltyPerHourWhenNeedy = 2.0
    /// Energy recovered per hour while napping (naps also give an instant boost on tap).
    static let energyPerSleepingHour = 20.0
    /// How long a nap lasts once started.
    static let napDuration: TimeInterval = 20 * 60

    /// Long absences are reconciled in one step but never below this: coming back after a
    /// week finds a scruffy, hungry, sleepy pet, not a tragedy.
    static let offlineFloor = 8.0
    /// Elapsed time beyond this is ignored when reconciling (device clock jumps, years away).
    static let maxReconcileGap: TimeInterval = 14 * 24 * 60 * 60

    // MARK: Actions

    struct Effect {
        var needs: [NeedKind: Double] = [:]
        var bond: Double = 0
        var cooldown: TimeInterval
    }

    static let effects: [PetAction: Effect] = [
        .feed: Effect(needs: [.fullness: 35, .mood: 5], bond: 4, cooldown: 20 * 60),
        .play: Effect(needs: [.mood: 25, .energy: -15], bond: 8, cooldown: 10 * 60),
        .groom: Effect(needs: [.cleanliness: 40, .mood: 5], bond: 4, cooldown: 15 * 60),
        .nap: Effect(needs: [.energy: 15], bond: 2, cooldown: 30 * 60),
        .pet: Effect(needs: [.mood: 8], bond: 3, cooldown: 60),
    ]
    /// Repeating an action inside its cooldown still does a little, but not much, and earns no bond.
    static let diminishedMultiplier = 0.25
    /// Playing when exhausted is allowed but gives a reduced mood boost.
    static let tiredEnergyThreshold = 20.0

    // MARK: Growth and bond

    /// Age in days at which each stage begins.
    static let youngAgeDays = 2.0
    static let adultAgeDays = 7.0
    /// Bond XP needed to reach each level; levels beyond the table grow by `bondStep`.
    static let bondLevels: [Double] = [0, 30, 80, 160, 280, 440]
    static let bondStep = 200.0

    // MARK: Island

    static let visitLength: TimeInterval = 8 * 60 * 60
    /// Without a fresh sync the Live Activity shows a truthful resting state after this.
    static let islandStaleAfter: TimeInterval = 3 * 60 * 60
    static let eatingShown: TimeInterval = 45
    static let playingShown: TimeInterval = 90
    static let happyShown: TimeInterval = 20
}
