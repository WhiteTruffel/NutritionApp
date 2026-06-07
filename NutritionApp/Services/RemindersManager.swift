import Foundation
import UserNotifications

final class RemindersManager {
    static let shared = RemindersManager()

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }

    func scheduleReminders(settings: RemindersSettings) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // Morning motivation
        if settings.morningMotivationEnabled {
            scheduleReminder(
                title: "Good morning!",
                body: "reminders.morning".localized(),
                time: settings.morningMotivationTime,
                identifier: "morningMotivation"
            )
        }

        // Breakfast reminder
        if settings.breakfastReminderEnabled {
            scheduleReminder(
                title: "Breakfast",
                body: "reminders.breakfast".localized(),
                time: settings.breakfastReminderTime,
                identifier: "breakfastReminder"
            )
        }

        // Lunch reminder
        if settings.lunchReminderEnabled {
            scheduleReminder(
                title: "Lunch",
                body: "reminders.lunch".localized(),
                time: settings.lunchReminderTime,
                identifier: "lunchReminder"
            )
        }

        // Dinner reminder
        if settings.dinnerReminderEnabled {
            scheduleReminder(
                title: "Dinner",
                body: "reminders.dinner".localized(),
                time: settings.dinnerReminderTime,
                identifier: "dinnerReminder"
            )
        }

        // Bedtime reminder
        if settings.bedtimeReminderEnabled {
            let bedtimeBefore = settings.bedtimeReminderTime.addingTimeInterval(Double(-settings.bedtimeBefore * 60))
            scheduleReminder(
                title: "Bedtime",
                body: "reminders.bedtime".localized(),
                time: bedtimeBefore,
                identifier: "bedtimeReminder"
            )
        }
    }

    private func scheduleReminder(title: String, body: String, time: Date, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        var trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule reminder \(identifier): \(error)")
            }
        }
    }

    func cancelReminder(_ identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func snoozeNotification(for minutes: Int) {
        let snoozeInterval = TimeInterval(minutes * 60)
        // Implementation depends on notification handling strategy
        // This would typically be called from a notification action handler
    }
}
