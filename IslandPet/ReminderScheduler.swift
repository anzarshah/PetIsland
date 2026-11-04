import Foundation
import Observation
import UserNotifications

/// Schedules at most one pending care reminder from `ReminderPlanner`, and routes taps on it.
@MainActor
@Observable
final class ReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderScheduler()

    private static let settingsKey = "islandpet.reminders.v1"
    private static let requestID = "islandpet.care"

    var settings: ReminderSettings {
        didSet {
            guard settings != oldValue else { return }
            save()
            if !isRescheduling {
                reschedule(for: PetStore.shared.pet)
            }
        }
    }
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var nextFireDate: Date?

    private let center = UNUserNotificationCenter.current()
    private var isRescheduling = false

    private override init() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(ReminderSettings.self, from: data) {
            settings = saved
        } else {
            settings = ReminderSettings()
        }
        super.init()
        center.delegate = self
        refreshAuthorization()
    }

    func refreshAuthorization() {
        Task {
            let status = await center.notificationSettings().authorizationStatus
            authorizationStatus = status
            if settings.enabled, status == .denied {
                settings.enabled = false
            }
        }
    }

    /// Asks for permission (only now, when the person turns reminders on) and enables them if granted.
    func enable() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        authorizationStatus = granted ? .authorized : .denied
        settings.enabled = granted
        return granted
    }

    func disable() {
        settings.enabled = false
    }

    /// Replaces the pending reminder with one that matches the pet's current needs, or removes it.
    func reschedule(for pet: PetState?) {
        isRescheduling = true
        defer { isRescheduling = false }

        center.removePendingNotificationRequests(withIdentifiers: [Self.requestID])
        nextFireDate = nil

        // A reminder still in the future never fired (we are cancelling it); one in the past was
        // delivered and should space out the next.
        if let last = settings.lastFireDate, last > .now {
            settings.lastFireDate = nil
        }

        guard let pet, settings.enabled,
              let plan = ReminderPlanner.plan(for: pet, settings: settings, now: .now) else { return }

        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default
        content.interruptionLevel = .active
        content.userInfo = ["route": "care"]
        content.threadIdentifier = "care"

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.requestID, content: content, trigger: trigger)
        center.add(request)
        nextFireDate = plan.fireDate
        settings.lastFireDate = plan.fireDate
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Self.settingsKey)
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run {
            AppServices.shared.pendingRoute = .care
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // The pet is already on screen; a banner would just repeat it.
        []
    }
}
