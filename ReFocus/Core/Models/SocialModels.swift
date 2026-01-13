import Foundation

// MARK: - Leaderboard Entry

struct LeaderboardEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    let username: String
    let avatarURL: String?
    let focusMinutesThisWeek: Int
    let currentStreak: Int
    let level: Int
    let rank: Int
    let isCurrentUser: Bool
    
    var focusTimeFormatted: String {
        let hours = focusMinutesThisWeek / 60
        let minutes = focusMinutesThisWeek % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Challenge

struct FocusChallenge: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var type: ChallengeType
    var targetMinutes: Int
    var startDate: Date
    var endDate: Date
    var creatorId: UUID
    var creatorName: String
    var participants: [ChallengeParticipant]
    var isPublic: Bool
    var inviteCode: String?
    var xpReward: Int
    
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    var isCompleted: Bool {
        Date() > endDate
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return max(0, days)
    }
    
    var progressPercentage: Double {
        guard let currentUser = participants.first(where: { $0.isCurrentUser }) else { return 0 }
        return min(1.0, Double(currentUser.minutesCompleted) / Double(targetMinutes))
    }
    
    enum ChallengeType: String, Codable, CaseIterable {
        case daily = "daily"
        case weekly = "weekly"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .custom: return "Custom"
            }
        }
    }
}

struct ChallengeParticipant: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    let username: String
    let avatarURL: String?
    var minutesCompleted: Int
    var isCurrentUser: Bool
    var hasCompleted: Bool
    var joinedAt: Date
    
    var progressFormatted: String {
        let hours = minutesCompleted / 60
        let minutes = minutesCompleted % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Friend

struct FocusFriend: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    let username: String
    let avatarURL: String?
    let level: Int
    let currentStreak: Int
    let status: FriendStatus
    let addedAt: Date
    
    enum FriendStatus: String, Codable {
        case pending = "pending"
        case accepted = "accepted"
        case blocked = "blocked"
    }
}

// MARK: - Leaderboard Time Frame

enum LeaderboardTimeFrame: String, CaseIterable {
    case daily = "Today"
    case weekly = "This Week"
    case monthly = "This Month"
    case allTime = "All Time"
}

// MARK: - Leaderboard Type

enum LeaderboardType: String, CaseIterable {
    case focusTime = "Focus Time"
    case streak = "Streak"
    case level = "Level"
    case sessions = "Sessions"
}
