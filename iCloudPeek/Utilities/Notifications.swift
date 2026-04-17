import Foundation
import UserNotifications

enum Notifications {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error { NSLog("Notification auth error: \(error)") }
        }
    }

    static func postQueueEmpty() {
        let content = UNMutableNotificationContent()
        content.title = "iCloud sincronizado"
        content.body = "Todas as transferências foram concluídas."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "icloudpeek.queue.empty.\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
