import NudgebarCore
import Foundation
import UserNotifications
import os.log

/// Native notification fallback used when full-screen alerts are off or Focus is
/// respected. Best-effort: requires a real app bundle for authorization.
@MainActor
final class NotificationDelivery {
    private static let logger = Logger(subsystem: "com.nudgebar", category: "Notifications")
    private var authorized = false

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error {
                Self.logger.warning("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            }
            Task { @MainActor in self?.authorized = granted }
        }
    }

    func deliver(event: AlertCandidate) {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.subtitle = event.calendarTitle
        content.body = "\(event.startDate.formatted(date: .omitted, time: .shortened))"
            + (event.location.map { " · \($0)" } ?? "")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "nudgebar-\(event.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Self.logger.warning("Notification delivery failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
