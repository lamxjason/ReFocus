import Foundation
import SwiftUI

/// Manages focus session statistics and achievements
@MainActor
final class StatsManager: ObservableObject {
    static let shared = StatsManager()

    // MARK: - Published Properties

    @Published var sessions: [FocusSession] = []
    @Published var achievements: [Achievement] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var totalFocusTime: TimeInterval = 0
    @Published var weeklyGoal: TimeInterval = 5 * 60 * 60 // 5 hours default
    @Published var weeklyProgress: TimeInterval = 0
    @Published var level: Int = 1
    @Published var xp: Int = 0

    // MARK: - Constants

    private let xpPerMinute = 10
    private let xpPerLevel = 1000
    private let streakBonusMultiplier = 1.5

    // MARK: - Computed Stats

    var todaySessions: [FocusSession] {
        sessions.filter { Calendar.current.isDateInToday($0.startTime) }
    }

    var thisWeekSessions: [FocusSession] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.startTime >= weekAgo }
    }

    var thisMonthSessions: [FocusSession] {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return sessions.filter { $0.startTime >= monthAgo }
    }

    var todayFocusTime: TimeInterval {
        todaySessions.reduce(0) { $0 + ($1.actualDurationSeconds.map { TimeInterval($0) } ?? 0) }
    }

    var averageSessionLength: TimeInterval {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0) { $0 + ($1.actualDurationSeconds.map { TimeInterval($0) } ?? 0) }
        return total / Double(sessions.count)
    }

    var completionRate: Double {
        guard !sessions.isEmpty else { return 0 }
        let completed = sessions.filter { $0.wasCompleted }.count
        return Double(completed) / Double(sessions.count)
    }

    var estimatedTimeSaved: TimeInterval {
        // Estimate 3x time saved from avoiding distractions
        totalFocusTime * 3
    }

    var weeklyGoalProgress: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(1.0, weeklyProgress / weeklyGoal)
    }

    var xpToNextLevel: Int {
        xpPerLevel - (xp % xpPerLevel)
    }

    var levelProgress: Double {
        Double(xp % xpPerLevel) / Double(xpPerLevel)
    }

    // MARK: - Daily Stats for Charts

    func dailyStats(for days: Int = 7) -> [DailyStat] {
        let calendar = Calendar.current
        var stats: [DailyStat] = []

        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            let daySessions = sessions.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
            let totalMinutes = daySessions.reduce(0) { $0 + ($1.actualDurationSeconds ?? 0) } / 60
            let completed = daySessions.filter { $0.wasCompleted }.count

            stats.append(DailyStat(
                date: date,
                focusMinutes: totalMinutes,
                sessionsCompleted: completed,
                sessionsTotal: daySessions.count
            ))
        }

        return stats.reversed()
    }

    // MARK: - Initialization

    private init() {
        loadData()
        calculateStats()
        checkAchievements()
    }

    // MARK: - Session Recording

    func recordSession(_ session: FocusSession) {
        sessions.append(session)

        // Award XP
        let minutes = (session.actualDurationSeconds ?? 0) / 60
        var earnedXP = minutes * xpPerMinute

        // Streak bonus
        if session.wasCompleted {
            earnedXP = Int(Double(earnedXP) * streakBonusMultiplier)
        }

        xp += earnedXP

        // Level up check
        let newLevel = (xp / xpPerLevel) + 1
        if newLevel > level {
            level = newLevel
            // Could trigger level up celebration here
        }

        calculateStats()
        checkAchievements()
        saveData()
    }

    // MARK: - Calculations

    private func calculateStats() {
        // Total focus time
        totalFocusTime = sessions.reduce(0) { $0 + ($1.actualDurationSeconds.map { TimeInterval($0) } ?? 0) }

        // Weekly progress
        weeklyProgress = thisWeekSessions.reduce(0) { $0 + ($1.actualDurationSeconds.map { TimeInterval($0) } ?? 0) }

        // Calculate streaks
        calculateStreaks()
    }

    private func calculateStreaks() {
        // Early exit if no sessions
        guard !sessions.isEmpty else {
            currentStreak = 0
            return
        }

        let calendar = Calendar.current
        var streak = 0
        var maxStreak = 0
        var currentDate = Date()
        var daysChecked = 0

        // Check consecutive days with completed sessions
        while daysChecked < 365 {
            daysChecked += 1

            let hasSession = sessions.contains { session in
                calendar.isDate(session.startTime, inSameDayAs: currentDate) && session.wasCompleted
            }

            if hasSession {
                streak += 1
                maxStreak = max(maxStreak, streak)
            } else if streak > 0 {
                // Allow one day gap for current streak
                if calendar.isDateInToday(currentDate) || calendar.isDateInYesterday(currentDate) {
                    // Continue checking
                } else {
                    break
                }
            } else {
                // No session and no streak started - exit
                break
            }

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previousDay
        }

        currentStreak = streak
        longestStreak = max(longestStreak, maxStreak)
    }

    // MARK: - Achievements

    private func checkAchievements() {
        var newAchievements: [Achievement] = []

        // First Session
        if sessions.count >= 1 && !hasAchievement(.firstSession) {
            newAchievements.append(Achievement.firstSession)
        }

        // Streak achievements
        if currentStreak >= 3 && !hasAchievement(.streak3) {
            newAchievements.append(Achievement.streak3)
        }
        if currentStreak >= 7 && !hasAchievement(.streak7) {
            newAchievements.append(Achievement.streak7)
        }
        if currentStreak >= 30 && !hasAchievement(.streak30) {
            newAchievements.append(Achievement.streak30)
        }

        // Time achievements
        let totalHours = totalFocusTime / 3600
        if totalHours >= 1 && !hasAchievement(.hour1) {
            newAchievements.append(Achievement.hour1)
        }
        if totalHours >= 10 && !hasAchievement(.hours10) {
            newAchievements.append(Achievement.hours10)
        }
        if totalHours >= 100 && !hasAchievement(.hours100) {
            newAchievements.append(Achievement.hours100)
        }

        // Session count achievements
        let completedCount = sessions.filter { $0.wasCompleted }.count
        if completedCount >= 10 && !hasAchievement(.sessions10) {
            newAchievements.append(Achievement.sessions10)
        }
        if completedCount >= 50 && !hasAchievement(.sessions50) {
            newAchievements.append(Achievement.sessions50)
        }
        if completedCount >= 100 && !hasAchievement(.sessions100) {
            newAchievements.append(Achievement.sessions100)
        }

        // Weekly goal
        if weeklyGoalProgress >= 1.0 && !hasAchievementThisWeek(.weeklyGoal) {
            newAchievements.append(Achievement.weeklyGoal)
        }

        achievements.append(contentsOf: newAchievements)
    }

    private func hasAchievement(_ type: AchievementType) -> Bool {
        achievements.contains { $0.type == type }
    }

    private func hasAchievementThisWeek(_ type: AchievementType) -> Bool {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return achievements.contains { $0.type == type && $0.unlockedAt >= weekAgo }
    }

    // MARK: - Goals

    func setWeeklyGoal(hours: Double) {
        weeklyGoal = hours * 3600
        saveData()
    }

    // MARK: - Persistence

    private func saveData() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "focusSessions")
        }
        if let encoded = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(encoded, forKey: "achievements")
        }
        UserDefaults.standard.set(xp, forKey: "userXP")
        UserDefaults.standard.set(level, forKey: "userLevel")
        UserDefaults.standard.set(longestStreak, forKey: "longestStreak")
        UserDefaults.standard.set(weeklyGoal, forKey: "weeklyGoal")
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: "focusSessions"),
           let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) {
            sessions = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "achievements"),
           let decoded = try? JSONDecoder().decode([Achievement].self, from: data) {
            achievements = decoded
        }
        xp = UserDefaults.standard.integer(forKey: "userXP")
        level = max(1, UserDefaults.standard.integer(forKey: "userLevel"))
        longestStreak = UserDefaults.standard.integer(forKey: "longestStreak")
        if UserDefaults.standard.double(forKey: "weeklyGoal") > 0 {
            weeklyGoal = UserDefaults.standard.double(forKey: "weeklyGoal")
        }
    }
}

// MARK: - Supporting Types

struct DailyStat: Identifiable {
    let id = UUID()
    let date: Date
    let focusMinutes: Int
    let sessionsCompleted: Int
    let sessionsTotal: Int

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

enum AchievementType: String, Codable {
    case firstSession
    case streak3
    case streak7
    case streak30
    case hour1
    case hours10
    case hours100
    case sessions10
    case sessions50
    case sessions100
    case weeklyGoal
}

struct Achievement: Identifiable, Codable {
    let id: UUID
    let type: AchievementType
    let name: String
    let description: String
    let icon: String
    let xpReward: Int
    let unlockedAt: Date

    init(type: AchievementType, name: String, description: String, icon: String, xpReward: Int) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.description = description
        self.icon = icon
        self.xpReward = xpReward
        self.unlockedAt = Date()
    }

    // Predefined milestones - Professional, understated names
    static let firstSession = Achievement(
        type: .firstSession,
        name: "First Session",
        description: "Session recorded",
        icon: "circle.fill",
        xpReward: 100
    )

    static let streak3 = Achievement(
        type: .streak3,
        name: "3 Days",
        description: "Consecutive days",
        icon: "square.stack.fill",
        xpReward: 200
    )

    static let streak7 = Achievement(
        type: .streak7,
        name: "7 Days",
        description: "One week consecutive",
        icon: "square.stack.fill",
        xpReward: 500
    )

    static let streak30 = Achievement(
        type: .streak30,
        name: "30 Days",
        description: "One month consecutive",
        icon: "square.stack.3d.up.fill",
        xpReward: 2000
    )

    static let hour1 = Achievement(
        type: .hour1,
        name: "1 Hour",
        description: "Total accumulated",
        icon: "clock",
        xpReward: 100
    )

    static let hours10 = Achievement(
        type: .hours10,
        name: "10 Hours",
        description: "Total accumulated",
        icon: "clock",
        xpReward: 500
    )

    static let hours100 = Achievement(
        type: .hours100,
        name: "100 Hours",
        description: "Total accumulated",
        icon: "clock.fill",
        xpReward: 2000
    )

    static let sessions10 = Achievement(
        type: .sessions10,
        name: "10 Sessions",
        description: "Completed",
        icon: "checkmark",
        xpReward: 300
    )

    static let sessions50 = Achievement(
        type: .sessions50,
        name: "50 Sessions",
        description: "Completed",
        icon: "checkmark",
        xpReward: 1000
    )

    static let sessions100 = Achievement(
        type: .sessions100,
        name: "100 Sessions",
        description: "Completed",
        icon: "checkmark.circle",
        xpReward: 3000
    )

    static let weeklyGoal = Achievement(
        type: .weeklyGoal,
        name: "Weekly Target",
        description: "Goal reached",
        icon: "flag",
        xpReward: 500
    )
}
