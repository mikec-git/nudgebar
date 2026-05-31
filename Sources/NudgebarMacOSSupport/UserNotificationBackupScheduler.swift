import NudgebarCore
import Foundation
import UserNotifications

public final class UserNotificationBackupScheduler {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    public func schedule(_ requests: [LocalNotificationBackupRequest]) async throws {
        for request in requests {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: request.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let notification = UNNotificationRequest(
                identifier: request.id,
                content: content,
                trigger: trigger
            )
            try await center.add(notification)
        }
    }

    public func removePending(ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
