import SwiftUI
import UserNotifications

@main
struct DuoFoldControlApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: UnfoldAppDelegate
    @StateObject private var controller = FoldLockController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
        }
    }
}

/// Opens the flap screen when the notification posted by the blocked-app screen's Flap Unlock
/// button is tapped.
final class UnfoldAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        // The shield's Flap Unlock button does nothing visible without this.
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        return true
    }

    @MainActor
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if response.notification.request.identifier == "flapUnlock" {
            FoldLockController.shared.flapUnlockRequested = true
        }
    }
}
