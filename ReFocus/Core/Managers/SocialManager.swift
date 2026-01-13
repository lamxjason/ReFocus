import Foundation
import Supabase
import Combine

/// Manages social features: leaderboards, challenges, and friends
@MainActor
final class SocialManager: ObservableObject {
    static let shared = SocialManager()
    
    // MARK: - Published State

    @Published private(set) var leaderboard: [LeaderboardEntry] = []
    @Published private(set) var activeChallenges: [FocusChallenge] = []
    @Published private(set) var availableChallenges: [FocusChallenge] = []
    @Published private(set) var friends: [FocusFriend] = []
    @Published private(set) var currentUserRank: Int?
    @Published private(set) var currentUsername: String?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    
    // MARK: - Settings
    
    @Published var selectedTimeFrame: LeaderboardTimeFrame = .weekly
    @Published var selectedLeaderboardType: LeaderboardType = .focusTime
    
    // MARK: - Dependencies
    
    private var supabase: SupabaseManager { .shared }
    
    private init() {}
    
    // MARK: - Leaderboard

    func fetchLeaderboard() async {
        guard supabase.isAuthenticated else { return }
        isLoading = true
        error = nil

        do {
            let userId = try supabase.requireUserId()

            if selectedTimeFrame == .allTime {
                // For all-time, use user_stats table
                await fetchAllTimeLeaderboard(userId: userId)
            } else {
                // For daily/weekly/monthly, aggregate from focus_sessions
                await fetchTimeFilteredLeaderboard(userId: userId)
            }

        } catch {
            self.error = error
        }

        isLoading = false
    }

    private func fetchAllTimeLeaderboard(userId: UUID) async {
        do {
            let response: [LeaderboardRow] = try await supabase.client
                .from("user_stats")
                .select("user_id, username, avatar_url, total_focus_seconds, current_streak, level")
                .order("total_focus_seconds", ascending: false)
                .limit(100)
                .execute()
                .value

            leaderboard = response.enumerated().map { index, row in
                LeaderboardEntry(
                    id: row.userId,
                    userId: row.userId,
                    username: row.username ?? "Anonymous",
                    avatarURL: row.avatarUrl,
                    focusMinutesThisWeek: row.totalFocusSeconds / 60,
                    currentStreak: row.currentStreak,
                    level: row.level,
                    rank: index + 1,
                    isCurrentUser: row.userId == userId
                )
            }

            currentUserRank = leaderboard.first(where: { $0.isCurrentUser })?.rank

        } catch {
            self.error = error
        }
    }

    private func fetchTimeFilteredLeaderboard(userId: UUID) async {
        do {
            let calendar = Calendar.current
            let now = Date()
            let startDate: Date

            switch selectedTimeFrame {
            case .daily:
                startDate = calendar.startOfDay(for: now)
            case .weekly:
                startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .monthly:
                startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            case .allTime:
                startDate = Date.distantPast
            }

            let formatter = ISO8601DateFormatter()
            let startDateString = formatter.string(from: startDate)

            // Query focus_sessions and aggregate by user
            let response: [SessionAggregateRow] = try await supabase.client
                .from("focus_sessions")
                .select("user_id, actual_duration_seconds")
                .gte("start_time", value: startDateString)
                .not("actual_duration_seconds", operator: .is, value: "null")
                .execute()
                .value

            // Aggregate focus time per user
            var userFocusTime: [UUID: Int] = [:]
            for row in response {
                userFocusTime[row.userId, default: 0] += row.actualDurationSeconds ?? 0
            }

            // Get user info for all users in the leaderboard
            let userIds = Array(userFocusTime.keys)
            guard !userIds.isEmpty else {
                leaderboard = []
                currentUserRank = nil
                return
            }

            let userIdsString = userIds.map { $0.uuidString }
            let userInfoResponse: [LeaderboardRow] = try await supabase.client
                .from("user_stats")
                .select("user_id, username, avatar_url, total_focus_seconds, current_streak, level")
                .in("user_id", values: userIdsString)
                .execute()
                .value

            // Build leaderboard entries
            var entries: [LeaderboardEntry] = userInfoResponse.compactMap { row in
                guard let focusSeconds = userFocusTime[row.userId] else { return nil }
                return LeaderboardEntry(
                    id: row.userId,
                    userId: row.userId,
                    username: row.username ?? "Anonymous",
                    avatarURL: row.avatarUrl,
                    focusMinutesThisWeek: focusSeconds / 60,
                    currentStreak: row.currentStreak,
                    level: row.level,
                    rank: 0, // Will be set after sorting
                    isCurrentUser: row.userId == userId
                )
            }

            // Sort by focus time and assign ranks
            entries.sort { $0.focusMinutesThisWeek > $1.focusMinutesThisWeek }
            leaderboard = entries.enumerated().map { index, entry in
                LeaderboardEntry(
                    id: entry.id,
                    userId: entry.userId,
                    username: entry.username,
                    avatarURL: entry.avatarURL,
                    focusMinutesThisWeek: entry.focusMinutesThisWeek,
                    currentStreak: entry.currentStreak,
                    level: entry.level,
                    rank: index + 1,
                    isCurrentUser: entry.isCurrentUser
                )
            }

            currentUserRank = leaderboard.first(where: { $0.isCurrentUser })?.rank

        } catch {
            self.error = error
        }
    }
    
    // MARK: - Challenges
    
    func fetchChallenges() async {
        guard supabase.isAuthenticated else { return }
        isLoading = true
        
        do {
            let userId = try supabase.requireUserId()
            
            // Fetch user's active challenges
            let activeResponse: [ChallengeRow] = try await supabase.client
                .from("challenges")
                .select("*, challenge_participants(*)")
                .contains("participant_ids", value: [userId.uuidString])
                .gte("end_date", value: ISO8601DateFormatter().string(from: Date()))
                .execute()
                .value
            
            activeChallenges = activeResponse.map { $0.toChallenge(currentUserId: userId) }
            
            // Fetch available public challenges
            let availableResponse: [ChallengeRow] = try await supabase.client
                .from("challenges")
                .select("*, challenge_participants(*)")
                .eq("is_public", value: true)
                .gte("end_date", value: ISO8601DateFormatter().string(from: Date()))
                .not("participant_ids", operator: .cs, value: [userId.uuidString])
                .limit(20)
                .execute()
                .value
            
            availableChallenges = availableResponse.map { $0.toChallenge(currentUserId: userId) }
            
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func createChallenge(
        name: String,
        description: String,
        type: FocusChallenge.ChallengeType,
        targetMinutes: Int,
        durationDays: Int,
        isPublic: Bool
    ) async throws -> FocusChallenge {
        let userId = try supabase.requireUserId()
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: durationDays, to: startDate)!
        let inviteCode = isPublic ? nil : generateInviteCode()
        
        let challenge = ChallengeInsert(
            name: name,
            description: description,
            type: type.rawValue,
            targetMinutes: targetMinutes,
            startDate: startDate,
            endDate: endDate,
            creatorId: userId,
            isPublic: isPublic,
            inviteCode: inviteCode,
            xpReward: calculateChallengeXP(targetMinutes: targetMinutes, durationDays: durationDays),
            participantIds: [userId.uuidString]
        )
        
        let response: ChallengeRow = try await supabase.client
            .from("challenges")
            .insert(challenge)
            .select()
            .single()
            .execute()
            .value
        
        let newChallenge = response.toChallenge(currentUserId: userId)
        activeChallenges.append(newChallenge)
        
        return newChallenge
    }
    
    func joinChallenge(_ challengeId: UUID) async throws {
        let userId = try supabase.requireUserId()
        
        // Add user to participants
        try await supabase.client
            .from("challenge_participants")
            .insert([
                "challenge_id": challengeId.uuidString,
                "user_id": userId.uuidString,
                "minutes_completed": "0"
            ])
            .execute()
        
        // Refresh challenges
        await fetchChallenges()
    }
    
    func joinChallengeByCode(_ code: String) async throws {
        let normalizedCode = code.uppercased().replacingOccurrences(of: "-", with: "")
        
        let response: [ChallengeRow] = try await supabase.client
            .from("challenges")
            .select()
            .eq("invite_code", value: normalizedCode)
            .limit(1)
            .execute()
            .value
        
        guard let challenge = response.first else {
            throw SocialError.challengeNotFound
        }
        
        try await joinChallenge(challenge.id)
    }
    
    func leaveChallenge(_ challengeId: UUID) async throws {
        let userId = try supabase.requireUserId()
        
        try await supabase.client
            .from("challenge_participants")
            .delete()
            .eq("challenge_id", value: challengeId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        activeChallenges.removeAll { $0.id == challengeId }
    }
    
    /// Update challenge progress after completing a session
    func updateChallengeProgress(minutesCompleted: Int) async {
        guard supabase.isAuthenticated else { return }
        
        do {
            let userId = try supabase.requireUserId()
            
            // Update all active challenges
            for challenge in activeChallenges where challenge.isActive {
                try await supabase.client
                    .rpc("increment_challenge_progress", params: [
                        "p_challenge_id": challenge.id.uuidString,
                        "p_user_id": userId.uuidString,
                        "p_minutes": String(minutesCompleted)
                    ])
                    .execute()
            }
            
            // Refresh to get updated progress
            await fetchChallenges()
            
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Friends
    
    func fetchFriends() async {
        guard supabase.isAuthenticated else { return }
        
        do {
            let userId = try supabase.requireUserId()
            
            let response: [FriendRow] = try await supabase.client
                .from("friends")
                .select("*, friend:friend_user_id(username, avatar_url, level, current_streak)")
                .eq("user_id", value: userId.uuidString)
                .eq("status", value: "accepted")
                .execute()
                .value
            
            friends = response.map { $0.toFriend() }
            
        } catch {
            self.error = error
        }
    }
    
    func addFriend(userId: UUID) async throws {
        let currentUserId = try supabase.requireUserId()
        
        try await supabase.client
            .from("friends")
            .insert([
                "user_id": currentUserId.uuidString,
                "friend_user_id": userId.uuidString,
                "status": "pending"
            ])
            .execute()
    }
    
    func acceptFriendRequest(_ friendId: UUID) async throws {
        try await supabase.client
            .from("friends")
            .update(["status": "accepted"])
            .eq("id", value: friendId.uuidString)
            .execute()
        
        await fetchFriends()
    }
    
    func removeFriend(_ friendId: UUID) async throws {
        try await supabase.client
            .from("friends")
            .delete()
            .eq("id", value: friendId.uuidString)
            .execute()

        friends.removeAll { $0.id == friendId }
    }

    /// Send a friend request by username
    func sendFriendRequestByUsername(_ username: String) async throws {
        let normalizedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()

        guard !normalizedUsername.isEmpty else {
            throw SocialError.invalidUsername
        }

        // Search for user by username (case-insensitive)
        let response: [FriendLookupRow] = try await supabase.client
            .from("user_stats")
            .select("user_id, username")
            .ilike("username", pattern: normalizedUsername)
            .limit(1)
            .execute()
            .value

        guard let foundUser = response.first else {
            throw SocialError.userNotFound
        }

        // Check if already friends or pending
        let currentUserId = try supabase.requireUserId()

        if foundUser.userId == currentUserId {
            throw SocialError.cannotAddSelf
        }

        // Check existing friendship
        let existingFriends: [FriendRow] = try await supabase.client
            .from("friends")
            .select()
            .or("and(user_id.eq.\(currentUserId.uuidString),friend_user_id.eq.\(foundUser.userId.uuidString)),and(user_id.eq.\(foundUser.userId.uuidString),friend_user_id.eq.\(currentUserId.uuidString))")
            .execute()
            .value

        if !existingFriends.isEmpty {
            throw SocialError.alreadyFriends
        }

        // Send the friend request
        try await addFriend(userId: foundUser.userId)
    }

    /// Fetch and cache the current user's username
    func fetchCurrentUsername() async {
        guard supabase.isAuthenticated else { return }

        do {
            let userId = try supabase.requireUserId()
            let response: [FriendLookupRow] = try await supabase.client
                .from("user_stats")
                .select("user_id, username")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            currentUsername = response.first?.username
        } catch {
            currentUsername = nil
        }
    }

    // MARK: - Helpers
    
    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
    
    private func calculateChallengeXP(targetMinutes: Int, durationDays: Int) -> Int {
        // Base XP based on difficulty
        let baseXP = targetMinutes * 2
        let durationMultiplier = min(2.0, 1.0 + Double(durationDays) / 14.0)
        return Int(Double(baseXP) * durationMultiplier)
    }
}

// MARK: - Database Row Types

private struct LeaderboardRow: Codable {
    let userId: UUID
    let username: String?
    let avatarUrl: String?
    let totalFocusSeconds: Int
    let currentStreak: Int
    let level: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case totalFocusSeconds = "total_focus_seconds"
        case currentStreak = "current_streak"
        case level
    }
}

private struct SessionAggregateRow: Codable {
    let userId: UUID
    let actualDurationSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case actualDurationSeconds = "actual_duration_seconds"
    }
}

private struct ChallengeRow: Codable {
    let id: UUID
    let name: String
    let description: String
    let type: String
    let targetMinutes: Int
    let startDate: Date
    let endDate: Date
    let creatorId: UUID
    let creatorName: String?
    let isPublic: Bool
    let inviteCode: String?
    let xpReward: Int
    let participantIds: [String]
    let participants: [ParticipantRow]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, type
        case targetMinutes = "target_minutes"
        case startDate = "start_date"
        case endDate = "end_date"
        case creatorId = "creator_id"
        case creatorName = "creator_name"
        case isPublic = "is_public"
        case inviteCode = "invite_code"
        case xpReward = "xp_reward"
        case participantIds = "participant_ids"
        case participants = "challenge_participants"
    }
    
    func toChallenge(currentUserId: UUID) -> FocusChallenge {
        FocusChallenge(
            id: id,
            name: name,
            description: description,
            type: FocusChallenge.ChallengeType(rawValue: type) ?? .custom,
            targetMinutes: targetMinutes,
            startDate: startDate,
            endDate: endDate,
            creatorId: creatorId,
            creatorName: creatorName ?? "Unknown",
            participants: participants?.map { $0.toParticipant(currentUserId: currentUserId) } ?? [],
            isPublic: isPublic,
            inviteCode: inviteCode,
            xpReward: xpReward
        )
    }
}

private struct ParticipantRow: Codable {
    let id: UUID
    let userId: UUID
    let username: String?
    let avatarUrl: String?
    let minutesCompleted: Int
    let hasCompleted: Bool
    let joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case minutesCompleted = "minutes_completed"
        case hasCompleted = "has_completed"
        case joinedAt = "joined_at"
    }
    
    func toParticipant(currentUserId: UUID) -> ChallengeParticipant {
        ChallengeParticipant(
            id: id,
            userId: userId,
            username: username ?? "Anonymous",
            avatarURL: avatarUrl,
            minutesCompleted: minutesCompleted,
            isCurrentUser: userId == currentUserId,
            hasCompleted: hasCompleted,
            joinedAt: joinedAt
        )
    }
}

private struct ChallengeInsert: Codable {
    let name: String
    let description: String
    let type: String
    let targetMinutes: Int
    let startDate: Date
    let endDate: Date
    let creatorId: UUID
    let isPublic: Bool
    let inviteCode: String?
    let xpReward: Int
    let participantIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case name, description, type
        case targetMinutes = "target_minutes"
        case startDate = "start_date"
        case endDate = "end_date"
        case creatorId = "creator_id"
        case isPublic = "is_public"
        case inviteCode = "invite_code"
        case xpReward = "xp_reward"
        case participantIds = "participant_ids"
    }
}

private struct FriendRow: Codable {
    let id: UUID
    let userId: UUID
    let friendUserId: UUID
    let status: String
    let createdAt: Date
    let friend: FriendInfo?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendUserId = "friend_user_id"
        case status
        case createdAt = "created_at"
        case friend
    }
    
    func toFriend() -> FocusFriend {
        FocusFriend(
            id: id,
            userId: friendUserId,
            username: friend?.username ?? "Unknown",
            avatarURL: friend?.avatarUrl,
            level: friend?.level ?? 1,
            currentStreak: friend?.currentStreak ?? 0,
            status: FocusFriend.FriendStatus(rawValue: status) ?? .pending,
            addedAt: createdAt
        )
    }
}

private struct FriendInfo: Codable {
    let username: String?
    let avatarUrl: String?
    let level: Int
    let currentStreak: Int
    
    enum CodingKeys: String, CodingKey {
        case username
        case avatarUrl = "avatar_url"
        case level
        case currentStreak = "current_streak"
    }
}

// MARK: - Friend Lookup

private struct FriendLookupRow: Codable {
    let userId: UUID
    let username: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
    }
}

// MARK: - Errors

enum SocialError: LocalizedError {
    case challengeNotFound
    case alreadyJoined
    case notAuthenticated
    case invalidUsername
    case userNotFound
    case cannotAddSelf
    case alreadyFriends

    var errorDescription: String? {
        switch self {
        case .challengeNotFound:
            return "Challenge not found or expired."
        case .alreadyJoined:
            return "You've already joined this challenge."
        case .notAuthenticated:
            return "Please sign in to use social features."
        case .invalidUsername:
            return "Please enter a valid username."
        case .userNotFound:
            return "No user found with that username."
        case .cannotAddSelf:
            return "You can't add yourself as a friend."
        case .alreadyFriends:
            return "You're already friends or have a pending request."
        }
    }
}
