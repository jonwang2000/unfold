import Foundation
import SwiftUI
import FamilyControls
import DeviceActivity

/// The app-side owner of `LockSettings`, shared by the UI and the App Intents (which run in the
/// app's process).
///
/// Invariants, both re-derived on launch because the system keeps them across launches:
/// - the shield store is `settings.applyShield(at: now)`, rewritten on every settings change and
///   by the monitor extension at each schedule or Flap Unlock boundary;
/// - DeviceActivity monitors exactly the schedule's windows, or none of them when the schedule is
///   off or registering any window failed, plus `.flapUnlock` while a Flap Unlock runs.
@MainActor
final class FoldLockController: ObservableObject {
    static let shared = FoldLockController()

    @Published private(set) var settings: LockSettings {
        didSet {
            settings.save()
            settings.applyShield(at: .now)
            if settings.schedule != oldValue.schedule { updateMonitoring() }
        }
    }
    @Published private(set) var scheduleError: String?
    @Published private(set) var flapUnlockError: String?
    @Published private(set) var lastEvent: String?
    /// Set when the blocked-app screen's Flap Unlock notification is tapped; ContentView opens the
    /// flap screen and resets it.
    @Published var flapUnlockRequested = false

    var selection: FamilyActivitySelection {
        get { settings.selection }
        set { settings.selection = newValue }
    }
    var schedule: LockSchedule {
        get { settings.schedule }
        set { settings.schedule = newValue }
    }
    var flapRule: FlapRule {
        get { settings.flapRule }
        set { settings.flapRule = newValue }
    }
    var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    private init() {
        settings = .load()
        sync()
    }

    func engage(source: String) {
        settings.isEngaged = true
        log("Engaged", source)
    }

    func release(source: String) {
        settings.isEngaged = false
        log("Released", source)
    }

    /// The reward for flapping: nothing locks for `flapRule.minutes`. A DeviceActivity interval
    /// ends with it so the monitor extension re-locks even if the app isn't running.
    func flapUnlock() {
        let now = Date.now
        let until = now.addingTimeInterval(TimeInterval(flapRule.minutes * 60))
        settings.flapUnlockedUntil = until
        log("Flap unlocked until \(until.formatted(date: .omitted, time: .shortened))", "Flap Unlock")

        let center = DeviceActivityCenter()
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]
        flapUnlockError = nil
        do {
            try center.startMonitoring(.flapUnlock, during: DeviceActivitySchedule(
                intervalStart: Calendar.current.dateComponents(fields, from: now),
                intervalEnd: Calendar.current.dateComponents(fields, from: until),
                repeats: false
            ))
        } catch {
            flapUnlockError = "Couldn’t set the re-lock timer, so the lock returns next time Unfold runs: \(error.localizedDescription)"
        }
    }

    /// Follows the hinge while Unfold is on screen. Only definite states move the lock; anything
    /// unknown leaves it untouched.
    func follow(_ hinge: DeviceHinge?) {
        guard let status = hinge?.status else { return }
        if status == .closed {
            engage(source: "Hinge (in app)")
        } else if status == .partiallyOpen || status == .fullyOpen {
            release(source: "Hinge (in app)")
        }
    }

    /// Debug only: `true` or `false` forces the lock over everything, `nil` hands control back.
    /// Clearing also ends any Flap Unlock, so each debug run starts from the plain fold state.
    func overrideLock(_ locked: Bool?) {
        var next = settings
        next.debugOverride = locked
        if locked == nil {
            next.flapUnlockedUntil = nil
            DeviceActivityCenter().stopMonitoring([.flapUnlock])
        }
        settings = next
        log(locked.map { $0 ? "Forced locked" : "Forced unlocked" } ?? "Override and Flap Unlock cleared", "Debug")
    }

    /// Rewrites the shield and schedule monitoring from current settings. Also call after Screen
    /// Time authorization is granted, since both are ignored or rejected before then.
    func sync() {
        settings.applyShield(at: .now)
        updateMonitoring()
    }

    private func updateMonitoring() {
        let center = DeviceActivityCenter()
        let scheduleActivities = { center.activities.filter { $0 != .flapUnlock } }
        center.stopMonitoring(scheduleActivities())
        scheduleError = nil
        guard schedule.isEnabled else { return }
        do {
            for day in schedule.weekdays.sorted() {
                let endDay = schedule.isOvernight ? day % 7 + 1 : day
                try center.startMonitoring(DeviceActivityName("schedule.\(day)"), during: DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: schedule.start / 60, minute: schedule.start % 60, weekday: day),
                    intervalEnd: DateComponents(hour: schedule.end / 60, minute: schedule.end % 60, weekday: endDay),
                    repeats: true
                ))
            }
        } catch {
            center.stopMonitoring(scheduleActivities())
            scheduleError = error.localizedDescription
        }
    }

    private func log(_ action: String, _ source: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        lastEvent = "\(action) by \(source) at \(time)"
    }
}

private extension DeviceActivityName {
    static let flapUnlock = DeviceActivityName("flapUnlock")
}
