import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Manages local and push notifications for the app
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    // MARK: - Published State

    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var pendingNotifications: Int = 0

    // MARK: - Notification Categories

    enum Category: String {
        case familyLockRequest = "FAMILY_LOCK_REQUEST"
        case familyLockApproved = "FAMILY_LOCK_APPROVED"
        case familyLockExpired = "FAMILY_LOCK_EXPIRED"
        case familyMemberJoined = "FAMILY_MEMBER_JOINED"
        case sessionReminder = "SESSION_REMINDER"
        case streakWarning = "STREAK_WARNING"
    }

    enum Action: String {
        case approveLock = "APPROVE_LOCK"
        case rejectLock = "REJECT_LOCK"
        case startSession = "START_SESSION"
        case viewFamily = "VIEW_FAMILY"
    }

    // MARK: - Init

    private init() {
        Task {
            await checkAuthorization()
            await registerCategories()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        isAuthorized = granted

        if granted {
            #if os(iOS)
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
            #endif
        }
    }

    func checkAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Category Registration

    private func registerCategories() async {
        let center = UNUserNotificationCenter.current()

        // Family lock request actions
        let approveAction = UNNotificationAction(
            identifier: Action.approveLock.rawValue,
            title: "Approve",
            options: [.foreground]
        )
        let rejectAction = UNNotificationAction(
            identifier: Action.rejectLock.rawValue,
            title: "Reject",
            options: [.destructive]
        )
        let lockRequestCategory = UNNotificationCategory(
            identifier: Category.familyLockRequest.rawValue,
            actions: [approveAction, rejectAction],
            intentIdentifiers: [],
            options: []
        )

        // Session reminder actions
        let startAction = UNNotificationAction(
            identifier: Action.startSession.rawValue,
            title: "Start Focus",
            options: [.foreground]
        )
        let sessionCategory = UNNotificationCategory(
            identifier: Category.sessionReminder.rawValue,
            actions: [startAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([lockRequestCategory, sessionCategory])
    }

    // MARK: - Family Notifications

    /// Notify user of incoming lock request
    func notifyLockRequest(from requesterName: String, durationMinutes: Int, lockId: UUID) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Focus Lock Request"
        content.body = "\(requesterName) wants you to focus for \(durationMinutes) minutes"
        content.sound = .default
        content.categoryIdentifier = Category.familyLockRequest.rawValue
        content.userInfo = ["lockId": lockId.uuidString]

        let request = UNNotificationRequest(
            identifier: "lock-request-\(lockId.uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Notify user their lock request was approved
    func notifyLockApproved(by targetName: String, durationMinutes: Int) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Focus Lock Approved"
        content.body = "\(targetName) accepted your focus lock for \(durationMinutes) minutes"
        content.sound = .default
        content.categoryIdentifier = Category.familyLockApproved.rawValue

        let request = UNNotificationRequest(
            identifier: "lock-approved-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Notify user their focus lock has expired
    func notifyLockExpired() async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Focus Lock Ended"
        content.body = "Your focus lock has expired. Great job staying focused!"
        content.sound = .default
        content.categoryIdentifier = Category.familyLockExpired.rawValue

        let request = UNNotificationRequest(
            identifier: "lock-expired-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Notify when a new member joins the family
    func notifyMemberJoined(memberName: String) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "New Family Member"
        content.body = "\(memberName) has joined your family group!"
        content.sound = .default
        content.categoryIdentifier = Category.familyMemberJoined.rawValue

        let request = UNNotificationRequest(
            identifier: "member-joined-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Scheduled Notifications

    /// Schedule a reminder for an upcoming focus session
    func scheduleSessionReminder(at date: Date, title: String) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Focus Session"
        content.body = title
        content.sound = .default
        content.categoryIdentifier = Category.sessionReminder.rawValue

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "session-reminder-\(date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule streak warning notification
    func scheduleStreakWarning(currentStreak: Int, hoursUntilLost: Int) {
        guard isAuthorized, hoursUntilLost > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "🔥 Streak Warning"
        content.body = "Your \(currentStreak)-day streak expires in \(hoursUntilLost) hours! Start a focus session to keep it alive."
        content.sound = .default
        content.categoryIdentifier = Category.streakWarning.rawValue

        // Schedule for 1 hour before expiry (or immediately if less than 1 hour)
        let delaySeconds = max(1, (hoursUntilLost - 1) * 3600)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(delaySeconds),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "streak-warning",
            content: content,
            trigger: trigger
        )

        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Stats Notifications

    /// Send notification for level up
    func sendLevelUpNotification(newLevel: Int, title: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "⬆️ Level Up! \(title)"
        content.body = "You've reached level \(newLevel)! Keep up the great work."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "level-up-\(newLevel)",
            content: content,
            trigger: nil
        )

        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    /// Send notification for streak milestone
    func sendStreakMilestoneNotification(streakDays: Int) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "🔥 Streak Milestone!"
        content.body = "Amazing! You've maintained a \(streakDays)-day streak!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "streak-milestone-\(streakDays)",
            content: content,
            trigger: nil
        )

        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    /// Send notification for achievement unlock
    func sendAchievementNotification(title: String, description: String, xpEarned: Int) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "🏆 \(title)"
        content.body = "\(description) (+\(xpEarned) XP)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "achievement-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Reward Notifications

    /// Send notification for earned reward
    func sendRewardNotification(rewardName: String, rarity: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "🎁 Bonus Reward!"
        content.body = rewardName
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "reward-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Cleanup

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
