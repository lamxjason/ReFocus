import Foundation
import SwiftUI

/// Manages focus session statistics and achievements
@MainActor
final class StatsManager: ObservableObject {
    static let shared = StatsManager()

    // MARK: - Published Properties

    @Published var sessions: [FocusSession] = []
    @Published var achievements: [Achievement] = []
    @Published var newlyUnlockedAchievements: [Achievement] = []
    @Published var pendingLevelUp: Int?  // Track level ups for celebration
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var streakFreezesAvailable: Int = 2  // Default 2 freezes
    @Published var streakFreezeUsedToday: Bool = false
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

    /// Whether the user's streak is at risk (has streak but no completed session today)
    var isStreakAtRisk: Bool {
        guard currentStreak > 0 else { return false }
        let todayCompleted = todaySessions.contains { $0.wasCompleted }
        return !todayCompleted
    }

    /// Hours remaining to protect streak
    var hoursRemainingToProtectStreak: Int {
        let calendar = Calendar.current
        guard let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) else {
            return 0
        }
        let remaining = endOfDay.timeIntervalSinceNow
        return max(0, Int(remaining / 3600))
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

        // Streak bonus for completed sessions
        if session.wasCompleted {
            earnedXP = Int(Double(earnedXP) * streakBonusMultiplier)
        }

        // Double XP bonus (from variable rewards - disabled in minimal mode)
        // Minimal mode users never earn doubleXP rewards, so this is effectively a no-op for them
        if !LocalPreferencesManager.shared.isMinimalModeEnabled {
            if RewardManager.shared.consumeDoubleXP() {
                earnedXP *= 2
            }
        }

        xp += earnedXP

        // Level up check
        let newLevel = (xp / xpPerLevel) + 1
        if newLevel > level {
            pendingLevelUp = newLevel
            level = newLevel
            
            // Send level up notification
            let title: String = {
                switch newLevel {
                case 1...5: return "Beginner"
                case 6...10: return "Focused"
                case 11...20: return "Dedicated"
                case 21...35: return "Master"
                case 36...50: return "Expert"
                case 51...75: return "Legend"
                case 76...100: return "Grandmaster"
                default: return "Transcendent"
                }
            }()
            NotificationManager.shared.sendLevelUpNotification(
                newLevel: newLevel,
                title: title
            )
        }

        calculateStats()
        checkAchievements()
        saveData()

        // Sync hero progression (disabled in minimal mode - hero system is deprecated)
        if !LocalPreferencesManager.shared.isMinimalModeEnabled {
            FocusHeroManager.shared.syncWithStats()
        }
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

        let previousStreak = currentStreak
        currentStreak = streak
        longestStreak = max(longestStreak, maxStreak)
        
        // Check for streak milestones
        let milestones = [7, 14, 30, 60, 100, 365]
        for milestone in milestones {
            if currentStreak >= milestone && previousStreak < milestone {
                NotificationManager.shared.sendStreakMilestoneNotification(streakDays: milestone)
                break
            }
        }
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

        // Add to achievements list and track newly unlocked
        if !newAchievements.isEmpty {
            achievements.append(contentsOf: newAchievements)
            newlyUnlockedAchievements.append(contentsOf: newAchievements)
            
            // Send notifications for each new achievement
            for achievement in newAchievements {
                NotificationManager.shared.sendAchievementNotification(
                    title: achievement.name,
                    description: achievement.description,
                    xpEarned: achievement.xpReward
                )
            }
        }
    }

    /// Clear newly unlocked achievements after displaying them
    func clearNewlyUnlockedAchievements() {
        newlyUnlockedAchievements.removeAll()
    }

    /// Get and clear the first newly unlocked achievement (for sequential display)
    func popNextUnlockedAchievement() -> Achievement? {
        guard !newlyUnlockedAchievements.isEmpty else { return nil }
        return newlyUnlockedAchievements.removeFirst()
    }

    /// Get and clear pending level up for celebration
    func popPendingLevelUp() -> Int? {
        guard let levelUp = pendingLevelUp else { return nil }
        pendingLevelUp = nil
        return levelUp
    }

    private func hasAchievement(_ type: AchievementType) -> Bool {
        achievements.contains { $0.type == type }
    }

    private func hasAchievementThisWeek(_ type: AchievementType) -> Bool {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return achievements.contains { $0.type == type && $0.unlockedAt >= weekAgo }
    }

    // MARK: - Streak Freezes

    /// Add a streak freeze (earned as reward)
    func addStreakFreeze() {
        streakFreezesAvailable = min(streakFreezesAvailable + 1, 5) // Max 5 freezes
        saveData()
    }

    /// Use a streak freeze to protect current streak
    /// Returns true if freeze was successfully used
    func useStreakFreeze() -> Bool {
        guard streakFreezesAvailable > 0 && !streakFreezeUsedToday else {
            return false
        }
        streakFreezesAvailable -= 1
        streakFreezeUsedToday = true
        saveData()
        return true
    }

    /// Reset daily streak freeze flag (called at start of new day)
    func resetDailyStreakFreezeFlag() {
        if streakFreezeUsedToday {
            streakFreezeUsedToday = false
            saveData()
        }
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
        UserDefaults.standard.set(streakFreezesAvailable, forKey: "streakFreezesAvailable")
        UserDefaults.standard.set(streakFreezeUsedToday, forKey: "streakFreezeUsedToday")
        
        // Update widget data
        let todayMinutes = todaySessions.reduce(0) { $0 + ($1.actualDurationSeconds ?? 0) } / 60
        let totalMinutes = Int(totalFocusTime / 60)
        WidgetDataManager.shared.updateStats(
            streak: currentStreak,
            level: level,
            todayMinutes: todayMinutes,
            totalMinutes: totalMinutes
        )
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
        // Load streak freezes - default to 2 if not set
        if UserDefaults.standard.object(forKey: "streakFreezesAvailable") != nil {
            streakFreezesAvailable = UserDefaults.standard.integer(forKey: "streakFreezesAvailable")
        }
        streakFreezeUsedToday = UserDefaults.standard.bool(forKey: "streakFreezeUsedToday")
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
    // Session achievements
    case firstSession = "first_session"
    case sessions10 = "sessions_10"
    case sessions50 = "sessions_50"
    case sessions100 = "sessions_100"

    // Streak achievements (key for retention)
    case streak3 = "streak_3"
    case streak7 = "streak_7"
    case streak14 = "streak_14"
    case streak30 = "streak_30"
    case streak100 = "streak_100"

    // Time achievements
    case hour1 = "hours_1"
    case hours10 = "hours_10"
    case hours50 = "hours_50"
    case hours100 = "hours_100"

    // Special achievements
    case weeklyGoal = "weekly_goal"
    case earlyBird = "early_bird"        // 5 sessions before 9 AM
    case nightOwl = "night_owl"          // 5 sessions after 9 PM
    case deepDiver = "deep_diver"        // 2+ hour session
    case hardModeHero = "hard_mode_hero" // 10 sessions in hard mode
    case perfectWeek = "perfect_week"    // 7 sessions in 7 days
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

    // New achievements based on research
    static let streak14 = Achievement(
        type: .streak14,
        name: "Fortnight Focus",
        description: "14 consecutive days",
        icon: "flame.fill",
        xpReward: 1000
    )

    static let streak100 = Achievement(
        type: .streak100,
        name: "Centurion",
        description: "100 consecutive days",
        icon: "crown.fill",
        xpReward: 10000
    )

    static let hours50 = Achievement(
        type: .hours50,
        name: "50 Hours",
        description: "Total accumulated",
        icon: "clock.badge.checkmark",
        xpReward: 1500
    )

    static let earlyBird = Achievement(
        type: .earlyBird,
        name: "Early Bird",
        description: "5 sessions before 9 AM",
        icon: "sunrise.fill",
        xpReward: 300
    )

    static let nightOwl = Achievement(
        type: .nightOwl,
        name: "Night Owl",
        description: "5 sessions after 9 PM",
        icon: "moon.stars.fill",
        xpReward: 300
    )

    static let deepDiver = Achievement(
        type: .deepDiver,
        name: "Deep Diver",
        description: "2+ hour session",
        icon: "figure.mind.and.body",
        xpReward: 500
    )

    static let hardModeHero = Achievement(
        type: .hardModeHero,
        name: "Hard Mode Hero",
        description: "10 sessions in hard mode",
        icon: "bolt.shield.fill",
        xpReward: 1000
    )

    static let perfectWeek = Achievement(
        type: .perfectWeek,
        name: "Perfect Week",
        description: "7 sessions in 7 days",
        icon: "star.circle.fill",
        xpReward: 700
    )
}
