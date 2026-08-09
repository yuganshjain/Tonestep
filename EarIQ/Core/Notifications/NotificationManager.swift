import UserNotifications
import Foundation

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let categoryID = "DAILY_PRACTICE"
    private let requestID = "eariq.daily.reminder"

    func requestPermission(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func checkPermission(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    func schedule(at components: DateComponents) {
        center.removePendingNotificationRequests(withIdentifiers: [requestID])

        let content = UNMutableNotificationContent()
        content.title = notificationTitle
        content.body = notificationBody
        content.sound = .default
        content.badge = 1

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
        center.add(request)
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        center.removeDeliveredNotifications(withIdentifiers: [requestID])
    }

    private var notificationTitle: String {
        let titles = [
            "🎵 Time to train your ears",
            "🔥 Keep your streak alive",
            "🎧 Your daily ear workout awaits",
            "🎹 5 minutes is all it takes",
            "👂 Your ears are waiting",
        ]
        return titles.randomElement()!
    }

    private var notificationBody: String {
        let bodies = [
            "A quick session keeps the streak going.",
            "Better ears open better music.",
            "Great musicians practice every day.",
            "Tap to start your daily session.",
            "Your future self will thank you.",
        ]
        return bodies.randomElement()!
    }
}
