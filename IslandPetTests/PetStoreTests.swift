import XCTest
@testable import IslandPet

final class PetStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        suite = "islandpet.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    @MainActor
    private func makeStore() -> PetStore {
        PetStore(defaults: defaults) { [self] in now }
    }

    @MainActor
    func testStartsEmptyWithoutSavedData() {
        XCTAssertNil(makeStore().pet)
    }

    @MainActor
    func testMigratesLegacyProfileIntoAPet() throws {
        let legacy = PetStore.LegacyProfile(species: .dog, coat: .midnight, name: "Biscuit")
        defaults.set(try JSONEncoder().encode(legacy), forKey: PetStore.legacyProfileKey)

        let store = makeStore()
        let pet = try XCTUnwrap(store.pet)
        XCTAssertEqual(pet.species, .dog)
        XCTAssertEqual(pet.coat, .midnight)
        XCTAssertEqual(pet.name, "Biscuit")
        XCTAssertEqual(pet.adoptedAt, now)
        XCTAssertEqual(pet.schemaVersion, PetState.currentSchemaVersion)
        XCTAssertNil(defaults.data(forKey: PetStore.legacyProfileKey), "the legacy profile is removed after migration")
        XCTAssertNotNil(defaults.data(forKey: PetStore.storageKey), "the migrated pet is saved in the new format")
    }

    @MainActor
    func testAdoptPersistsAndReloadsTheSamePet() throws {
        let store = makeStore()
        store.adopt(species: .cat, coat: .snow, name: "Luna", personality: .cozy)
        let adopted = try XCTUnwrap(store.pet)

        let reloaded = try XCTUnwrap(makeStore().pet)
        XCTAssertEqual(reloaded.id, adopted.id)
        XCTAssertEqual(reloaded.name, "Luna")
        XCTAssertEqual(reloaded.personality, .cozy)
        XCTAssertEqual(reloaded.adoptedAt, now)
    }

    @MainActor
    func testActionsFlowThroughTheStoreAndPersist() throws {
        let store = makeStore()
        store.adopt(species: .cat, coat: .honey, name: "Mochi", personality: .curious)
        now = now.addingTimeInterval(3600)

        let outcome = try XCTUnwrap(store.perform(.play))
        XCTAssertEqual(outcome.action, .play)
        XCTAssertEqual(store.lastOutcome, outcome)
        XCTAssertEqual(store.pet?.care.played, now)

        let reloaded = try XCTUnwrap(makeStore().pet)
        XCTAssertEqual(reloaded.care.played, now)
        XCTAssertEqual(reloaded.bond, GameBalance.effects[.play]?.bond)
    }

    @MainActor
    func testReloadReconcilesElapsedTime() throws {
        let store = makeStore()
        store.adopt(species: .dog, coat: .ash, name: "Pip", personality: .bouncy)
        now = now.addingTimeInterval(10 * 3600)
        let reloaded = try XCTUnwrap(makeStore().pet)
        XCTAssertEqual(reloaded.needs.fullness, Needs.fresh.fullness - 40, accuracy: 0.001)
        XCTAssertEqual(reloaded.lastReconciledAt, now)
    }

    @MainActor
    func testEditingKeepsIdentityAgeNeedsAndBond() throws {
        let store = makeStore()
        store.adopt(species: .cat, coat: .honey, name: "Mochi", personality: .curious)
        now = now.addingTimeInterval(2 * 3600)
        store.perform(.feed)
        let before = try XCTUnwrap(store.pet)

        store.edit(name: "Mochi II", coat: .patches, accessory: .bow, personality: .bouncy)
        let after = try XCTUnwrap(store.pet)
        XCTAssertEqual(after.id, before.id)
        XCTAssertEqual(after.adoptedAt, before.adoptedAt)
        XCTAssertEqual(after.needs, before.needs)
        XCTAssertEqual(after.bond, before.bond)
        XCTAssertEqual(after.name, "Mochi II")
        XCTAssertEqual(after.coat, .patches)
        XCTAssertEqual(after.accessory, .bow)
    }

    @MainActor
    func testReleaseRemovesThePetExplicitly() {
        let store = makeStore()
        store.adopt(species: .cat, coat: .honey, name: "Mochi", personality: .curious)
        store.release()
        XCTAssertNil(store.pet)
        XCTAssertNil(defaults.data(forKey: PetStore.storageKey))
        XCTAssertNil(makeStore().pet)
    }

    @MainActor
    func testChangeEventsReachListeners() {
        let store = makeStore()
        var events: [PetStoreEvent] = []
        store.onChange = { _, event in events.append(event) }
        store.adopt(species: .cat, coat: .honey, name: "Mochi", personality: .curious)
        store.perform(.pet)
        store.edit(name: "Momo")
        XCTAssertEqual(events, [.adopted, .acted(.pet), .edited])
    }

    @MainActor
    func testIslandSnapshotCarriesThePetIdentity() {
        let pet = PetState(adoptedAt: now, species: .dog, coat: .snow, name: "Pip")
        let attributes = PetAttributes(pet: pet, visitStartedAt: now)
        XCTAssertEqual(attributes.petID, pet.id)
        XCTAssertEqual(attributes.name, "Pip")
        XCTAssertEqual(attributes.visitEndsAt, now.addingTimeInterval(GameBalance.visitLength))
        let snapshot = PetAttributes.ContentState(pet: pet, now: now)
        XCTAssertEqual(snapshot.stage, .baby)
        XCTAssertEqual(snapshot.islandState, .idle)
    }
}
