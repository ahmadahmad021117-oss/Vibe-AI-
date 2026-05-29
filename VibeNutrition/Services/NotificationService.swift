import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let dailyReminderID = "vibe.daily.reminder"
    private let weeklySummaryID = "vibe.weekly.summary"

    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            return granted
        }
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    /// Reschedule both notifications based on the user's current pref.
    /// Requests system permission if not yet determined, so this must only be
    /// called from an explicit user action (onboarding choice, Settings toggle)
    /// — never at app launch, or the prompt appears at a random spot.
    func apply(pref: NotificationPref) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID, weeklySummaryID])

        guard pref != .off else { return }
        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return }

        if pref == .full {
            await scheduleDaily(center: center)
        }
        await scheduleWeekly(center: center)
    }

    /// Reschedule notifications for an already-decided user WITHOUT ever
    /// triggering the system permission prompt. Safe to call at app launch:
    /// if permission was never granted, it simply does nothing.
    func rescheduleIfAuthorized(pref: NotificationPref) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID, weeklySummaryID])

        guard pref != .off else { return }
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        guard authorized else { return }

        if pref == .full {
            await scheduleDaily(center: center)
        }
        await scheduleWeekly(center: center)
    }

    private func scheduleDaily(center: UNUserNotificationCenter) async {
        let content = UNMutableNotificationContent()
        content.title = "Log today's meals"
        content.body = "A 10-second check-in keeps your plan honest."
        content.sound = .default

        var trigger = DateComponents()
        trigger.hour = 19
        trigger.minute = 30

        let req = UNNotificationRequest(
            identifier: dailyReminderID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )
        try? await center.add(req)
    }

    private func scheduleWeekly(center: UNUserNotificationCenter) async {
        let content = UNMutableNotificationContent()
        content.title = "Your weekly progress is ready"
        content.body = "See how the past 7 days stacked up against your goal."
        content.sound = .default

        var trigger = DateComponents()
        trigger.weekday = 1   // Sunday
        trigger.hour = 9
        trigger.minute = 0

        let req = UNNotificationRequest(
            identifier: weeklySummaryID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )
        try? await center.add(req)
    }
}
