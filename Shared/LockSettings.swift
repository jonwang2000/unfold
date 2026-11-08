import Foundation
import FamilyControls
import ManagedSettings

/// Everything that decides whether apps are blocked. Stored in the App Group because the
/// schedule monitor extension runs in its own process and must read the same values as the app.
struct LockSettings: Codable, Equatable {
    var selection = FamilyActivitySelection()
    /// The last fold state reported by Shortcuts or the in-app hinge. Nothing else can read the
    /// hinge, so the monitor extension trusts this value at schedule boundaries.
    var isEngaged = false
    var schedule = LockSchedule()

    private static let defaults = UserDefaults(suiteName: "group.com.jonathanwang.DuoFoldControl")!
    private static let key = "settings"

    static func load() -> LockSettings {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode(LockSettings.self, from: data) else {
            return LockSettings()
        }
        return saved
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            Self.defaults.set(data, forKey: Self.key)
        }
    }

    func isLocking(at date: Date) -> Bool {
        isEngaged && schedule.allows(date)
    }

    /// The only writer of the shield store, which is therefore a pure function of these settings
    /// and the clock.
    func applyShield(at date: Date) {
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("foldLock"))
        guard isLocking(at: date) else {
            store.clearAllSettings()
            return
        }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }
}

/// The hours and weekdays when folding locks apps. A window that ends at or before its start
/// runs past midnight and belongs to the weekday it starts on.
struct LockSchedule: Codable, Equatable {
    var isEnabled = false
    /// Minutes after midnight.
    var start = 9 * 60
    var end = 17 * 60
    /// Calendar weekday numbers, where 1 is Sunday.
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]

    var isOvernight: Bool { end <= start }

    func allows(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return true }
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        let minute = parts.hour! * 60 + parts.minute!
        let today = parts.weekday!
        guard isOvernight else {
            return weekdays.contains(today) && (start..<end).contains(minute)
        }
        let yesterday = today == 1 ? 7 : today - 1
        return (weekdays.contains(today) && minute >= start) || (weekdays.contains(yesterday) && minute < end)
    }
}
