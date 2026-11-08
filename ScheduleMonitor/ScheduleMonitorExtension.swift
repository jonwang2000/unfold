import DeviceActivity
import Foundation

/// Re-applies the shield when a scheduled window opens or closes, since the app may not be running.
class ScheduleMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        reapply()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        reapply()
    }

    private func reapply() {
        // Judge a minute ahead so a callback delivered slightly early still lands on the right
        // side of the boundary. DeviceActivity rejects windows under 15 minutes, so this never skips one.
        LockSettings.load().applyShield(at: .now.addingTimeInterval(60))
    }
}
