import SwiftUI

/// Account (sign in, sign out, delete) and care reminders.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                AccountSection()
                RemindersSections()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { ReminderScheduler.shared.refreshAuthorization() }
            }
        }
    }
}

#Preview {
    SettingsSheet()
}
