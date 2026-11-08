import Foundation
import FamilyControls
import ManagedSettings

/// Owns the user's app selection and the shield store. Shared by the UI and the App Intents,
/// which run in the app's process, so plain UserDefaults is enough for persistence.
///
/// Invariant: the shield store is a pure function of `isEngaged` and `selection`, and
/// `syncShield()` is its only writer.
@MainActor
final class FoldLockController: ObservableObject {
    static let shared = FoldLockController()

    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("foldLock"))
    private let defaults = UserDefaults.standard
    private let selectionKey = "foldLock.selection"
    private let engagedKey = "foldLock.engaged"

    @Published var selection: FamilyActivitySelection {
        didSet {
            if let data = try? JSONEncoder().encode(selection) {
                defaults.set(data, forKey: selectionKey)
            }
            syncShield()
        }
    }
    @Published private(set) var isEngaged: Bool {
        didSet {
            defaults.set(isEngaged, forKey: engagedKey)
            syncShield()
        }
    }
    @Published private(set) var lastEvent: String?

    var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    private init() {
        if let data = defaults.data(forKey: selectionKey),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = saved
        } else {
            selection = FamilyActivitySelection()
        }
        isEngaged = defaults.bool(forKey: engagedKey)
        // The store outlives this process; re-derive it in case it drifted while we weren't running.
        syncShield()
    }

    func engage(source: String) {
        isEngaged = true
        log("Engaged", source)
    }

    func release(source: String) {
        isEngaged = false
        log("Released", source)
    }

    /// Writes the store from current state. Also call after Screen Time authorization is granted,
    /// since writes made before then don't take effect.
    func syncShield() {
        guard isEngaged else {
            store.clearAllSettings()
            return
        }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    private func log(_ action: String, _ source: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        lastEvent = "\(action) by \(source) at \(time)"
    }
}
