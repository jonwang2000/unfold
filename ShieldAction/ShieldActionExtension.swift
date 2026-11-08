import ManagedSettings
import UserNotifications

/// Handles the buttons on the blocked-app screen. A shield can't open another app, so Flap Unlock
/// posts a notification instead, and tapping it opens Unfold's flap screen.
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    private func respond(to action: ShieldAction, _ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard action == .secondaryButtonPressed else {
            completionHandler(.close)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Flap Unlock"
        content.body = "Tap to open Unfold and start flapping."
        // The app matches this identifier to open the flap screen (UnfoldAppDelegate).
        let request = UNNotificationRequest(identifier: "flapUnlock", content: content, trigger: nil)
        // Leave the shield up so the banner lands over it instead of after the app-close animation.
        UNUserNotificationCenter.current().add(request) { _ in completionHandler(.none) }
    }
}
