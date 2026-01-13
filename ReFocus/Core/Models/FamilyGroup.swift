import Foundation

/// Represents a Family Plan group with shared subscription
struct FamilyGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var ownerId: UUID
    var ownerName: String
    var inviteCode: String
    var members: [FamilyMember]
    var createdAt: Date
    var subscriptionId: String? // StoreKit subscription ID

    var memberCount: Int { members.count }
    var availableSlots: Int { max(0, 5 - memberCount) }
    var isFull: Bool { memberCount >= 5 }

    static let maxMembers = 5
}

/// A member of a family group
struct FamilyMember: Identifiable, Codable, Equatable {
    let id: UUID
    let oderId: UUID
    var username: String
    var avatarURL: String?
    var role: MemberRole
    var joinedAt: Date

    // Accountability stats
    var currentStreak: Int
    var level: Int
    var focusMinutesThisWeek: Int
    var lastActiveAt: Date?

    enum MemberRole: String, Codable {
        case owner = "owner"
        case member = "member"
    }

    var focusTimeFormatted: String {
        let hours = focusMinutesThisWeek / 60
        let minutes = focusMinutesThisWeek % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

/// Accountability request between family members
struct AccountabilityLock: Identifiable, Codable {
    let id: UUID
    let familyGroupId: UUID
    let requesterId: UUID
    let requesterName: String
    let targetUserId: UUID
    let targetUserName: String
    var status: LockStatus
    var durationMinutes: Int
    var reason: String?
    var createdAt: Date
    var expiresAt: Date?

    enum LockStatus: String, Codable {
        case pending = "pending"
        case approved = "approved"
        case rejected = "rejected"
        case active = "active"
        case completed = "completed"
        case cancelled = "cancelled"
    }

    var isActive: Bool {
        status == .active && (expiresAt == nil || expiresAt! > Date())
    }
}

/// Family activity feed item
struct FamilyActivity: Identifiable, Codable {
    let id: UUID
    let familyGroupId: UUID
    let oderId: UUID
    let username: String
    let activityType: ActivityType
    let description: String
    let createdAt: Date

    enum ActivityType: String, Codable {
        case sessionCompleted = "session_completed"
        case streakMilestone = "streak_milestone"
        case levelUp = "level_up"
        case achievementUnlocked = "achievement_unlocked"
        case memberJoined = "member_joined"
        case lockRequested = "lock_requested"
        case lockApproved = "lock_approved"
    }
}
