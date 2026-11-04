import Foundation

/// The pet's four needs, each 0...100 where 100 is fully satisfied.
struct Needs: Codable, Equatable, Sendable {
    var fullness: Double
    var energy: Double
    var cleanliness: Double
    var mood: Double

    static let fresh = Needs(fullness: 90, energy: 90, cleanliness: 95, mood: 85)

    subscript(kind: NeedKind) -> Double {
        get {
            switch kind {
            case .fullness: fullness
            case .energy: energy
            case .cleanliness: cleanliness
            case .mood: mood
            }
        }
        set {
            let clamped = min(GameBalance.needMax, max(0, newValue))
            switch kind {
            case .fullness: fullness = clamped
            case .energy: energy = clamped
            case .cleanliness: cleanliness = clamped
            case .mood: mood = clamped
            }
        }
    }

    /// The need most in want of care, lowest first.
    var lowest: (kind: NeedKind, value: Double) {
        NeedKind.allCases
            .map { ($0, self[$0]) }
            .min { $0.1 < $1.1 }!
    }

    var hasLowNeed: Bool { lowest.value < GameBalance.lowNeed }
}

/// When each kind of care last happened; drives cooldowns and "last fed" captions.
struct CareLog: Codable, Equatable, Sendable {
    var fed: Date?
    var played: Date?
    var groomed: Date?
    var napped: Date?
    var petted: Date?

    subscript(action: PetAction) -> Date? {
        get {
            switch action {
            case .feed: fed
            case .play: played
            case .groom: groomed
            case .nap: napped
            case .pet: petted
            }
        }
        set {
            switch action {
            case .feed: fed = newValue
            case .play: played = newValue
            case .groom: groomed = newValue
            case .nap: napped = newValue
            case .pet: petted = newValue
            }
        }
    }
}

/// What the pet most recently did, so the home screen and island can show a reaction.
struct RecentActivity: Codable, Equatable, Sendable {
    var action: PetAction
    var at: Date
}

/// The single persistent pet. Everything the game knows lives here and is saved as JSON.
struct PetState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion = PetState.currentSchemaVersion
    var id: UUID
    var adoptedAt: Date
    var species: PetSpecies
    var coat: PetCoat
    var name: String
    var personality: PetPersonality
    var accessory: PetAccessory
    var needs: Needs
    /// Bond experience; see `PetReducer.bondLevel`.
    var bond: Double
    var lastReconciledAt: Date
    var care: CareLog
    /// Set while a nap is in progress.
    var sleepingUntil: Date?
    var recentActivity: RecentActivity?

    init(
        id: UUID = UUID(),
        adoptedAt: Date,
        species: PetSpecies,
        coat: PetCoat,
        name: String,
        personality: PetPersonality = .curious,
        accessory: PetAccessory = .none,
        needs: Needs = .fresh,
        bond: Double = 0
    ) {
        self.id = id
        self.adoptedAt = adoptedAt
        self.species = species
        self.coat = coat
        self.name = name
        self.personality = personality
        self.accessory = accessory
        self.needs = needs
        self.bond = bond
        lastReconciledAt = adoptedAt
        care = CareLog()
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? species.defaultName : trimmed
    }

    func ageDays(at now: Date) -> Double {
        max(0, now.timeIntervalSince(adoptedAt)) / 86_400
    }

    func growthStage(at now: Date) -> GrowthStage {
        let days = ageDays(at: now)
        if days < GameBalance.youngAgeDays { return .baby }
        if days < GameBalance.adultAgeDays { return .young }
        return .adult
    }

    func isSleeping(at now: Date) -> Bool {
        guard let sleepingUntil else { return false }
        return now < sleepingUntil
    }
}
