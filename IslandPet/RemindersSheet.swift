import SwiftUI

/// Optional care reminders: one consolidated nudge, quiet hours, a frequency choice, an off switch.
/// Form sections, hosted by `SettingsSheet`.
struct RemindersSections: View {
    @State private var requesting = false

    private var scheduler: ReminderScheduler { .shared }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { scheduler.settings.enabled },
            set: { newValue in
                if newValue {
                    requesting = true
                    Task {
                        _ = await scheduler.enable()
                        requesting = false
                    }
                } else {
                    scheduler.disable()
                }
            }
        )
    }

    var body: some View {
        Section {
            Toggle("Care reminders", isOn: enabledBinding)
                .disabled(requesting)
        } header: {
            Text("Reminders")
        } footer: {
            Text("One gentle heads-up when a need is about to run low — never more than one at a time, and nothing urgent. Your pet is fine without them.")
        }

        if scheduler.authorizationStatus == .denied {
            Section {
                Label("Notifications are turned off for Island Pet in Settings.", systemImage: "bell.slash")
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                }
            }
        }

        if scheduler.settings.enabled {
            Section("How often") {
                Picker("Frequency", selection: Binding(
                    get: { scheduler.settings.frequency },
                    set: { scheduler.settings.frequency = $0 }
                )) {
                    ForEach(ReminderFrequency.allCases) { frequency in
                        Text(frequency.title).tag(frequency)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                Picker("Quiet from", selection: Binding(
                    get: { scheduler.settings.quietStartHour },
                    set: { scheduler.settings.quietStartHour = $0 }
                )) {
                    ForEach(0..<24, id: \.self) { hour in Text(hourLabel(hour)).tag(hour) }
                }
                Picker("Until", selection: Binding(
                    get: { scheduler.settings.quietEndHour },
                    set: { scheduler.settings.quietEndHour = $0 }
                )) {
                    ForEach(0..<24, id: \.self) { hour in Text(hourLabel(hour)).tag(hour) }
                }
            } header: {
                Text("Quiet hours")
            } footer: {
                Text("Reminders that would land in quiet hours wait until they end.")
            }

            if let next = scheduler.nextFireDate {
                Section("Next reminder") {
                    Text(next, format: .dateTime.weekday(.wide).hour().minute())
                }
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(.dateTime.hour())
    }
}
