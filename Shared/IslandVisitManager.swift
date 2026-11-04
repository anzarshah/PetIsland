import ActivityKit
import Foundation
import Observation

/// Manages the pet's "island visit": the Live Activity that mirrors the pet for up to eight
/// hours. The pet is never stored here; this only publishes snapshots of `PetStore`.
@MainActor
@Observable
final class IslandVisitManager {
    static let shared = IslandVisitManager()

    private(set) var visit: Activity<PetAttributes>?
    private(set) var lastError: String?
    private var lastSnapshot: PetAttributes.ContentState?

    var isVisiting: Bool { visit != nil }
    var visitEndsAt: Date? { visit?.attributes.visitEndsAt }
    var areActivitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    private init() {
        reattach()
    }

    /// Finds a visit that is still running from an earlier launch, and forgets ones that ended.
    func reattach() {
        let running = Activity<PetAttributes>.activities.filter { [.active, .stale].contains($0.activityState) }
        visit = running.first
        lastSnapshot = visit?.content.state
    }

    /// Starts a visit for `pet`. If another visit is still running, the new one is requested
    /// first and the old one ended only after the request succeeds, so a failure never leaves
    /// the island empty.
    func startVisit(for pet: PetState, now: Date = .now) async {
        reattach()
        let attributes = PetAttributes(pet: pet, visitStartedAt: now)
        let snapshot = PetAttributes.ContentState(pet: pet, now: now)
        do {
            let started = try Activity.request(attributes: attributes, content: content(for: snapshot, now: now), pushType: nil)
            if let previous = visit, previous.id != started.id {
                await previous.end(nil, dismissalPolicy: .immediate)
            }
            visit = started
            lastSnapshot = snapshot
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func endVisit() async {
        for running in Activity<PetAttributes>.activities {
            await running.end(nil, dismissalPolicy: .immediate)
        }
        visit = nil
        lastSnapshot = nil
    }

    /// Publishes a fresh snapshot if anything meaningful changed. Safe to call often.
    func sync(with pet: PetState?, now: Date = .now) async {
        reattach()
        guard let visit else { return }
        guard let pet, pet.id == visit.attributes.petID else {
            await endVisit()
            return
        }
        let snapshot = PetAttributes.ContentState(pet: pet, now: now)
        guard snapshot != lastSnapshot else { return }
        await visit.update(content(for: snapshot, now: now))
        lastSnapshot = snapshot
    }

    private func content(for snapshot: PetAttributes.ContentState, now: Date) -> ActivityContent<PetAttributes.ContentState> {
        let staleAt = snapshot.timedRange?.upperBound.addingTimeInterval(5 * 60) ?? now.addingTimeInterval(GameBalance.islandStaleAfter)
        return ActivityContent(state: snapshot, staleDate: staleAt)
    }
}
