import AppIntents

/// Exposes the intents to Siri, Shortcuts, and the Action button.
struct IslandPetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartIslandVisitIntent(),
            phrases: [
                "Send my \(.applicationName) to the island",
                "Show my \(.applicationName) in the Dynamic Island",
            ],
            shortTitle: "Visit the Island",
            systemImageName: "pawprint.fill"
        )
        AppShortcut(
            intent: PetActionIntent(),
            phrases: [
                "Care for my \(.applicationName)",
            ],
            shortTitle: "Care for Pet",
            systemImageName: "heart.fill"
        )
    }
}
