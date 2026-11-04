import Foundation

enum ReminderFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    /// At most one reminder a day.
    case gentle
    /// At most one every eight hours.
    case regular

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle: "Once a day at most"
        case .regular: "A few times a day"
        }
    }

    var minimumGap: TimeInterval {
        switch self {
        case .gentle: 20 * 60 * 60
        case .regular: 8 * 60 * 60
        }
    }
}

struct ReminderSettings: Codable, Equatable, Sendable {
    var enabled = false
    var frequency: ReminderFrequency = .gentle
    /// Quiet hours, in the device's local time. Reminders inside the window move to its end.
    var quietStartHour = 22
    var quietEndHour = 8
    /// When the most recent reminder was scheduled to fire; used to space reminders out.
    var lastFireDate: Date?

    var hasQuietHours: Bool { quietStartHour != quietEndHour }
}

struct ReminderPlan: Equatable, Sendable {
    var fireDate: Date
    var need: NeedKind
    var title: String
    var body: String
}

/// Decides if and when one consolidated care reminder should fire. Pure: pass `now` and a calendar.
enum ReminderPlanner {
    /// Reminders never fire sooner than this after being scheduled.
    static let minimumLead: TimeInterval = 5 * 60
    /// If a need is already low, remind after this rather than immediately.
    static let alreadyLowLead: TimeInterval = 15 * 60

    static func plan(for pet: PetState, settings: ReminderSettings, now: Date, calendar: Calendar = .current) -> ReminderPlan? {
        guard settings.enabled else { return nil }

        var fireDate: Date
        if let hours = PetReducer.hoursUntilNeedLow(pet, now: now) {
            fireDate = now.addingTimeInterval(hours * 3600)
        } else {
            fireDate = now.addingTimeInterval(alreadyLowLead)
        }
        if let last = settings.lastFireDate {
            fireDate = max(fireDate, last.addingTimeInterval(settings.frequency.minimumGap))
        }
        fireDate = max(fireDate, now.addingTimeInterval(minimumLead))
        fireDate = movedOutsideQuietHours(fireDate, settings: settings, calendar: calendar)

        let predicted = PetReducer.reconcile(pet, now: fireDate).needs.lowest.kind
        return ReminderPlan(fireDate: fireDate, need: predicted, title: title(for: predicted, name: pet.displayName), body: body(for: predicted, name: pet.displayName))
    }

    static func isQuiet(_ date: Date, settings: ReminderSettings, calendar: Calendar) -> Bool {
        guard settings.hasQuietHours else { return false }
        let hour = calendar.component(.hour, from: date)
        if settings.quietStartHour < settings.quietEndHour {
            return hour >= settings.quietStartHour && hour < settings.quietEndHour
        }
        return hour >= settings.quietStartHour || hour < settings.quietEndHour
    }

    /// Moves a date that falls in quiet hours to the end of that quiet window.
    static func movedOutsideQuietHours(_ date: Date, settings: ReminderSettings, calendar: Calendar) -> Date {
        guard isQuiet(date, settings: settings, calendar: calendar) else { return date }
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = settings.quietEndHour
        components.minute = 0
        guard var end = calendar.date(from: components) else { return date }
        if end <= date {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return end
    }

    private static func title(for need: NeedKind, name: String) -> String {
        switch need {
        case .fullness: "\(name) could use a snack"
        case .energy: "\(name) is getting sleepy"
        case .cleanliness: "\(name) is a bit scruffy"
        case .mood: "\(name) misses you"
        }
    }

    private static func body(for need: NeedKind, name: String) -> String {
        switch need {
        case .fullness: "Fullness is getting low. A quick meal would hit the spot."
        case .energy: "A short nap would help \(name) recharge."
        case .cleanliness: "A little grooming when you have a moment."
        case .mood: "A minute of play would make \(name)'s day."
        }
    }
}
