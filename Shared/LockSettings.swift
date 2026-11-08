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
    /// Earned by a Flap Unlock; nothing locks before this date except a debug override.
    var flapUnlockedUntil: Date?
    /// Set from the debug section only. Forces the lock on (true) or off (false) over everything.
    var debugOverride: Bool?
    var schedule = LockSchedule()
    var flapRule = FlapRule()

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
        if let debugOverride { return debugOverride }
        if let flapUnlockedUntil, date < flapUnlockedUntil { return false }
        return isEngaged && schedule.allows(date)
    }

    /// Offered whenever apps are locked. The saved fold state can be stale (the hinge only
    /// reports to Unfold while it's on screen), and flapping corrects it.
    func canFlapUnlock(at date: Date) -> Bool {
        debugOverride == nil && isLocking(at: date)
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

    // Fields added after a release decode with their defaults, so updating never wipes the
    // chosen apps.
    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = LockSettings()
        selection = try container.decodeIfPresent(FamilyActivitySelection.self, forKey: .selection) ?? fallback.selection
        isEngaged = try container.decodeIfPresent(Bool.self, forKey: .isEngaged) ?? fallback.isEngaged
        flapUnlockedUntil = try container.decodeIfPresent(Date.self, forKey: .flapUnlockedUntil)
        debugOverride = try container.decodeIfPresent(Bool.self, forKey: .debugOverride)
        schedule = try container.decodeIfPresent(LockSchedule.self, forKey: .schedule) ?? fallback.schedule
        flapRule = try container.decodeIfPresent(FlapRule.self, forKey: .flapRule) ?? fallback.flapRule
    }
}

/// What a Flap Unlock costs: close and reopen the phone `flaps` times in the app to unlock for
/// `minutes`.
struct FlapRule: Codable, Equatable {
    var flaps = 10
    /// DeviceActivity rejects intervals under 15 minutes, and the re-lock rides on one.
    var minutes = 15
}

/// When folding locks apps; outside it, folding has no effect. A window that ends at or before its
/// start runs past midnight and belongs to the weekday it starts on.
struct LockSchedule: Codable, Equatable {
    var isEnabled = false
    /// Minutes after midnight.
    var start = 9 * 60
    var end = 17 * 60
    /// Calendar weekday numbers, where 1 is Sunday.
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]

    var isOvernight: Bool { end <= start }

    /// Whether folding locks apps at `date`: always when the schedule is off.
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
