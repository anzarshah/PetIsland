import Foundation
import Observation

/// Where to land when the app opens from a notification or the Live Activity.
enum AppRoute: Equatable {
    case care
}

/// Wires the store to everything that reacts to it: the island visit and care reminders.
@MainActor
@Observable
final class AppServices {
    static let shared = AppServices()

    var pendingRoute: AppRoute?

    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        PetStore.shared.onChange = { [weak self] pet, event in
            self?.petDidChange(pet, event: event)
        }
        IslandVisitManager.shared.reattach()
        Task { await IslandVisitManager.shared.sync(with: PetStore.shared.pet) }
        ReminderScheduler.shared.reschedule(for: PetStore.shared.pet)
    }

    func didBecomeActive() {
        PetStore.shared.reconcile()
        IslandVisitManager.shared.reattach()
        Task { await IslandVisitManager.shared.sync(with: PetStore.shared.pet) }
    }

    func handle(_ url: URL) {
        guard url.scheme == "islandpet" else { return }
        pendingRoute = .care
    }

    private func petDidChange(_ pet: PetState?, event: PetStoreEvent) {
        Task { await IslandVisitManager.shared.sync(with: pet) }
        switch event {
        case .acted, .reconciled, .adopted, .released, .loaded:
            ReminderScheduler.shared.reschedule(for: pet)
        case .edited:
            break
        }
    }
}
