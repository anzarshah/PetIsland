import ActivityKit
import Foundation

/// The Live Activity shows a snapshot of the pet. The pet itself lives in `PetStore`.
struct PetAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var islandState: IslandState
        var caption: String
        var lowestNeed: NeedKind
        var lowestValue: Int
        var bondLevel: Int
        var stage: GrowthStage
        /// Present while a timed action (eating, playing, napping) is in progress.
        var timedRange: ClosedRange<Date>?
        /// The one care action worth offering right now.
        var suggestedAction: PetAction
    }

    var petID: UUID
    var name: String
    var species: PetSpecies
    var coat: PetCoat
    var accessory: PetAccessory
    var visitStartedAt: Date
    var visitEndsAt: Date

    init(pet: PetState, visitStartedAt: Date, visitLength: TimeInterval = GameBalance.visitLength) {
        petID = pet.id
        name = pet.displayName
        species = pet.species
        coat = pet.coat
        accessory = pet.accessory
        self.visitStartedAt = visitStartedAt
        visitEndsAt = visitStartedAt.addingTimeInterval(visitLength)
    }

    var visitRange: ClosedRange<Date> { visitStartedAt...visitEndsAt }
}

extension PetAttributes.ContentState {
    /// Builds the snapshot the island should show for a pet right now.
    init(pet: PetState, now: Date) {
        let (state, timed) = PetReducer.islandState(for: pet, now: now)
        let lowest = PetReducer.reconcile(pet, now: now).needs.lowest
        islandState = state
        caption = PetReducer.caption(for: pet, now: now)
        lowestNeed = lowest.kind
        lowestValue = Int(lowest.value.rounded())
        bondLevel = PetReducer.bondLevel(pet.bond).level
        stage = pet.growthStage(at: now)
        timedRange = timed
        suggestedAction = PetReducer.suggestion(for: pet, now: now).action ?? .play
    }

    static let preview = PetAttributes.ContentState(
        islandState: .idle, caption: "Sunbathing on the island", lowestNeed: .mood, lowestValue: 72,
        bondLevel: 2, stage: .young, timedRange: nil, suggestedAction: .play
    )
}

extension PetAttributes {
    static let preview = PetAttributes(
        pet: PetState(adoptedAt: .now.addingTimeInterval(-3 * 86_400), species: .cat, coat: .honey, name: "Mochi"),
        visitStartedAt: .now
    )
}
