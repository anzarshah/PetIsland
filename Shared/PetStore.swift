import Foundation
import Observation

/// Why the store changed, for listeners that sync the island or reschedule reminders.
enum PetStoreEvent: Equatable, Sendable {
    case loaded
    case reconciled
    case acted(PetAction)
    case edited
    case adopted
    case released
}

/// The one place the pet is read and written. Every path — the app, Live Activity intents,
/// Shortcuts — goes through here, so there is exactly one pet and one version of the truth.
@MainActor
@Observable
final class PetStore {
    static let shared = PetStore(defaults: .standard)

    static let storageKey = "islandpet.pet.v1"
    /// Pre-game profile (species, coat, name) that earlier builds saved.
    static let legacyProfileKey = "islandpet.profile"

    private(set) var pet: PetState?
    private(set) var lastOutcome: ActionOutcome?
    var onChange: ((PetState?, PetStoreEvent) -> Void)?

    private let defaults: UserDefaults
    private let clock: () -> Date

    init(defaults: UserDefaults, clock: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.clock = clock
        load()
    }

    var now: Date { clock() }

    // MARK: Loading and migration

    func load() {
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(PetState.self, from: data) {
            pet = PetReducer.reconcile(Self.migrate(saved), now: now)
        } else if let migrated = Self.migrateLegacyProfile(from: defaults, now: now) {
            pet = migrated
            defaults.removeObject(forKey: Self.legacyProfileKey)
        } else {
            pet = nil
        }
        if pet != nil { save() }
        onChange?(pet, .loaded)
    }

    /// Upgrades older schema versions in place. Add a step here whenever `currentSchemaVersion` bumps.
    static func migrate(_ saved: PetState) -> PetState {
        var pet = saved
        pet.schemaVersion = PetState.currentSchemaVersion
        return pet
    }

    /// Turns the old species/coat/name profile into a pet so current users keep theirs.
    static func migrateLegacyProfile(from defaults: UserDefaults, now: Date) -> PetState? {
        guard let data = defaults.data(forKey: legacyProfileKey),
              let legacy = try? JSONDecoder().decode(LegacyProfile.self, from: data) else { return nil }
        return PetState(adoptedAt: now, species: legacy.species, coat: legacy.coat, name: legacy.name)
    }

    struct LegacyProfile: Codable {
        var species: PetSpecies
        var coat: PetCoat
        var name: String
    }

    // MARK: Mutations

    /// Brings needs up to date. Call when the app comes to the foreground.
    func reconcile() {
        guard let current = pet else { return }
        let updated = PetReducer.reconcile(current, now: now)
        guard updated != current else { return }
        commit(updated, event: .reconciled)
    }

    @discardableResult
    func perform(_ action: PetAction) -> ActionOutcome? {
        guard let current = pet else { return nil }
        let (updated, outcome) = PetReducer.apply(action, to: current, now: now)
        lastOutcome = outcome
        commit(updated, event: .acted(action))
        return outcome
    }

    func adopt(species: PetSpecies, coat: PetCoat, name: String, personality: PetPersonality, accessory: PetAccessory = .none) {
        let newPet = PetState(adoptedAt: now, species: species, coat: coat, name: name, personality: personality, accessory: accessory)
        lastOutcome = nil
        commit(newPet, event: .adopted)
    }

    /// Cosmetic edits keep age, needs and bond.
    func edit(name: String? = nil, coat: PetCoat? = nil, accessory: PetAccessory? = nil, personality: PetPersonality? = nil) {
        guard var updated = pet else { return }
        if let name { updated.name = name }
        if let coat { updated.coat = coat }
        if let accessory { updated.accessory = accessory }
        if let personality { updated.personality = personality }
        guard updated != pet else { return }
        commit(updated, event: .edited)
    }

    /// Says goodbye to the current pet. Explicit and separate from adoption on purpose.
    func release() {
        pet = nil
        lastOutcome = nil
        defaults.removeObject(forKey: Self.storageKey)
        onChange?(nil, .released)
    }

    private func commit(_ updated: PetState, event: PetStoreEvent) {
        pet = updated
        save()
        onChange?(updated, event)
    }

    private func save() {
        guard let pet, let data = try? JSONEncoder().encode(pet) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
