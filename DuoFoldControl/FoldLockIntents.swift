import AppIntents

// Type names are what saved Shortcuts automations reference, so rename titles, not types.

struct EngageFoldLockIntent: AppIntent {
    static var title: LocalizedStringResource = "Lock Apps"
    static var description = IntentDescription("Locks your chosen apps. Use with the “Closed” automation.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        FoldLockController.shared.engage(source: "Shortcut")
        return .result()
    }
}

struct ReleaseFoldLockIntent: AppIntent {
    static var title: LocalizedStringResource = "Unlock Apps"
    static var description = IntentDescription("Unlocks your chosen apps. Use with the “Opened” automation.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        FoldLockController.shared.release(source: "Shortcut")
        return .result()
    }
}

struct FoldLockShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: EngageFoldLockIntent(),
            phrases: ["Lock apps with \(.applicationName)"],
            shortTitle: "Lock Apps",
            systemImageName: "lock"
        )
        AppShortcut(
            intent: ReleaseFoldLockIntent(),
            phrases: ["Unlock apps with \(.applicationName)"],
            shortTitle: "Unlock Apps",
            systemImageName: "lock.open"
        )
    }
}
