import AppIntents
import Foundation

extension PetAction: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Pet Action")

    static let caseDisplayRepresentations: [PetAction: DisplayRepresentation] = [
        .pet: "Pet",
        .feed: "Feed",
        .play: "Play",
        .groom: "Groom",
        .nap: "Nap",
    ]
}

/// Runs in the app's process when a button in the Live Activity is tapped (or from Shortcuts).
/// Changes the one saved pet, then refreshes the island snapshot.
struct PetActionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Care for Pet"
    static let description: IntentDescription? = IntentDescription("Pet, feed, play with, groom, or tuck in your Island Pet.")

    @Parameter(title: "Action")
    var action: PetAction

    init() {}

    init(action: PetAction) {
        self.action = action
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = PetStore.shared
        store.perform(action)
        await IslandVisitManager.shared.sync(with: store.pet)
        return .result()
    }
}

/// Starts an island visit (a Live Activity) for the pet, for use from Shortcuts or the Action
/// button. Each visit is explicitly started and ends after eight hours.
struct StartIslandVisitIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Send Pet to the Island"
    static let description: IntentDescription? = IntentDescription("Shows your pet in the Dynamic Island for up to eight hours.")

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = PetStore.shared
        store.reconcile()
        guard let pet = store.pet else { return .result() }
        let island = IslandVisitManager.shared
        if island.isVisiting {
            await island.sync(with: pet)
        } else {
            await island.startVisit(for: pet)
        }
        return .result()
    }
}
