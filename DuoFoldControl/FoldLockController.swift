import Foundation
import FamilyControls
import DeviceActivity

/// The app-side owner of `LockSettings`, shared by the UI and the App Intents (which run in the
/// app's process).
///
/// Invariants, both re-derived on launch because the system keeps them across launches:
/// - the shield store is `settings.applyShield(at: now)`, rewritten on every settings change and
///   by the monitor extension at each schedule boundary;
/// - DeviceActivity monitors exactly the schedule's windows, or nothing when the schedule is off
///   or registering any window failed.
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
    @Published private(set) var lastEvent: String?

    var selection: FamilyActivitySelection {
        get { settings.selection }
        set { settings.selection = newValue }
    }
    var schedule: LockSchedule {
        get { settings.schedule }
        set { settings.schedule = newValue }
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

    /// Rewrites the shield and schedule monitoring from current settings. Also call after Screen
    /// Time authorization is granted, since both are ignored or rejected before then.
    func sync() {
        settings.applyShield(at: .now)
        updateMonitoring()
    }

    private func updateMonitoring() {
        let center = DeviceActivityCenter()
        center.stopMonitoring()
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
            center.stopMonitoring()
            scheduleError = error.localizedDescription
        }
    }

    private func log(_ action: String, _ source: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        lastEvent = "\(action) by \(source) at \(time)"
    }
}
