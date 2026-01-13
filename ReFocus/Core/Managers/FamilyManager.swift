import Foundation
import Combine
import Supabase

/// Manages Family Plan features: groups, members, accountability
@MainActor
final class FamilyManager: ObservableObject {
    static let shared = FamilyManager()

    // MARK: - Published State

    @Published private(set) var familyGroup: FamilyGroup?
    @Published private(set) var pendingLocks: [AccountabilityLock] = []
    @Published private(set) var activeLocks: [AccountabilityLock] = []
    @Published private(set) var activityFeed: [FamilyActivity] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?

    // MARK: - Enforcement Callbacks

    /// Called when a family lock becomes active (user approved lock request)
    var onFamilyLockActivated: ((AccountabilityLock) -> Void)?
    /// Called when a family lock expires or is completed
    var onFamilyLockDeactivated: (() -> Void)?

    // MARK: - Computed

    var isInFamily: Bool { familyGroup != nil }
    var isOwner: Bool {
        guard let group = familyGroup, let userId = try? supabase.requireUserId() else { return false }
        return group.ownerId == userId
    }
    var currentMember: FamilyMember? {
        guard let group = familyGroup, let userId = try? supabase.requireUserId() else { return nil }
        return group.members.first { $0.oderId == userId }
    }

    // MARK: - Dependencies

    private var supabase: SupabaseManager { .shared }
    private var notifications: NotificationManager { .shared }

    private init() {}

    // MARK: - Real-time Subscriptions

    private var realtimeChannel: Any?
    private(set) var isConnected: Bool = false

    /// Subscribe to real-time updates for family data
    func subscribe() async {
        guard supabase.isAuthenticated, let group = familyGroup else { return }

        let channel = supabase.client.realtimeV2.channel("family-\(group.id.uuidString)")

        // Listen for lock changes
        let lockChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "accountability_locks",
            filter: "family_group_id=eq.\(group.id.uuidString)"
        )

        // Listen for activity feed changes
        let activityChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "family_activities",
            filter: "family_group_id=eq.\(group.id.uuidString)"
        )

        // Listen for member changes
        let memberChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "family_members",
            filter: "family_group_id=eq.\(group.id.uuidString)"
        )

        await channel.subscribe()

        // Handle lock changes
        Task {
            for await change in lockChanges {
                await handleLockChange(change)
            }
        }

        // Handle activity changes
        Task {
            for await _ in activityChanges {
                await fetchActivityFeed()
            }
        }

        // Handle member changes
        Task {
            for await _ in memberChanges {
                await fetchFamilyGroup()
            }
        }

        realtimeChannel = channel
        isConnected = true
    }

    /// Unsubscribe from real-time updates
    func unsubscribe() async {
        realtimeChannel = nil
        isConnected = false
    }

    private func handleLockChange(_ change: AnyAction) async {
        guard let userId = try? supabase.requireUserId() else { return }

        switch change {
        case .insert(let action):
            // New lock request - check if it's for us
            if let lock = try? action.decodeRecord(as: AccountabilityLockRow.self, decoder: JSONDecoder()) {
                if lock.targetUserId == userId && lock.status == "pending" {
                    pendingLocks.append(lock.toLock())
                    // Send notification for new lock request
                    await notifications.notifyLockRequest(
                        from: lock.requesterName,
                        durationMinutes: lock.durationMinutes,
                        lockId: lock.id
                    )
                }
            }
        case .update(let action):
            // Lock status changed
            if let lock = try? action.decodeRecord(as: AccountabilityLockRow.self, decoder: JSONDecoder()) {
                // Remove from pending if no longer pending
                pendingLocks.removeAll { $0.id == lock.id }

                if lock.targetUserId == userId {
                    if lock.status == "pending" {
                        pendingLocks.append(lock.toLock())
                    } else if lock.status == "active" {
                        let activeLock = lock.toLock()
                        if activeLock.isActive {
                            activeLocks.append(activeLock)
                            onFamilyLockActivated?(activeLock)
                        }
                    }
                }

                // Check if lock expired/completed
                if lock.status == "completed" || lock.status == "cancelled" {
                    activeLocks.removeAll { $0.id == lock.id }
                    if activeLocks.isEmpty {
                        onFamilyLockDeactivated?()
                    }
                }
            }
        case .delete:
            await fetchPendingLocks()
        default:
            break
        }
    }

    // MARK: - Family Group Management

    func fetchFamilyGroup() async {
        guard supabase.isAuthenticated else { return }
        isLoading = true

        do {
            let userId = try supabase.requireUserId()

            // Check if user is in a family group
            let memberRows: [FamilyMemberRow] = try await supabase.client
                .from("family_members")
                .select("*, family_groups(*)")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            if let memberRow = memberRows.first, let groupRow = memberRow.familyGroup {
                // Fetch all members of this group
                let allMembers: [FamilyMemberRow] = try await supabase.client
                    .from("family_members")
                    .select("*, user_stats:user_id(username, avatar_url, level, current_streak, total_focus_minutes)")
                    .eq("family_group_id", value: groupRow.id.uuidString)
                    .execute()
                    .value

                familyGroup = FamilyGroup(
                    id: groupRow.id,
                    name: groupRow.name,
                    ownerId: groupRow.ownerId,
                    ownerName: groupRow.ownerName,
                    inviteCode: groupRow.inviteCode,
                    members: allMembers.map { $0.toMember() },
                    createdAt: groupRow.createdAt,
                    subscriptionId: groupRow.subscriptionId
                )

                // Fetch pending locks and activity
                await fetchPendingLocks()
                await fetchActivityFeed()
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func createFamilyGroup(name: String) async throws -> FamilyGroup {
        let userId = try supabase.requireUserId()
        let stats = StatsManager.shared

        let inviteCode = generateInviteCode()

        // Create the group
        let groupInsert = FamilyGroupInsert(
            name: name,
            ownerId: userId,
            ownerName: "Anonymous",
            inviteCode: inviteCode
        )

        let groupRow: FamilyGroupRow = try await supabase.client
            .from("family_groups")
            .insert(groupInsert)
            .select()
            .single()
            .execute()
            .value

        // Add owner as first member
        try await supabase.client
            .from("family_members")
            .insert([
                "family_group_id": groupRow.id.uuidString,
                "user_id": userId.uuidString,
                "role": "owner"
            ])
            .execute()

        await fetchFamilyGroup()
        return familyGroup!
    }

    func joinFamilyByCode(_ code: String) async throws {
        let userId = try supabase.requireUserId()
        let normalizedCode = code.uppercased().replacingOccurrences(of: "-", with: "")

        // Find the group
        let groups: [FamilyGroupRow] = try await supabase.client
            .from("family_groups")
            .select()
            .eq("invite_code", value: normalizedCode)
            .limit(1)
            .execute()
            .value

        guard let group = groups.first else {
            throw FamilyError.groupNotFound
        }

        // Check if group is full
        let memberCount: Int = try await supabase.client
            .from("family_members")
            .select("id", head: true, count: .exact)
            .eq("family_group_id", value: group.id.uuidString)
            .execute()
            .count ?? 0

        if memberCount >= FamilyGroup.maxMembers {
            throw FamilyError.groupFull
        }

        // Join the group
        try await supabase.client
            .from("family_members")
            .insert([
                "family_group_id": group.id.uuidString,
                "user_id": userId.uuidString,
                "role": "member"
            ])
            .execute()

        // Post activity
        try await postActivity(.memberJoined, description: "joined the family")

        await fetchFamilyGroup()
    }

    func leaveFamily() async throws {
        guard let group = familyGroup else { return }
        let userId = try supabase.requireUserId()

        if isOwner {
            // Owner leaving deletes the entire group
            try await supabase.client
                .from("family_groups")
                .delete()
                .eq("id", value: group.id.uuidString)
                .execute()
        } else {
            // Member just removes themselves
            try await supabase.client
                .from("family_members")
                .delete()
                .eq("family_group_id", value: group.id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
        }

        familyGroup = nil
        pendingLocks = []
        activeLocks = []
        activityFeed = []
    }

    func removeMember(_ memberId: UUID) async throws {
        guard isOwner, let group = familyGroup else {
            throw FamilyError.notAuthorized
        }

        try await supabase.client
            .from("family_members")
            .delete()
            .eq("family_group_id", value: group.id.uuidString)
            .eq("user_id", value: memberId.uuidString)
            .execute()

        await fetchFamilyGroup()
    }

    // MARK: - Accountability Locks

    func requestLock(for targetUserId: UUID, durationMinutes: Int, reason: String?) async throws {
        guard let group = familyGroup else { return }
        let userId = try supabase.requireUserId()

        guard let targetMember = group.members.first(where: { $0.oderId == targetUserId }) else {
            throw FamilyError.memberNotFound
        }

        let lockInsert: [String: String] = [
            "family_group_id": group.id.uuidString,
            "requester_id": userId.uuidString,
            "requester_name": currentMember?.username ?? "Someone",
            "target_user_id": targetUserId.uuidString,
            "target_user_name": targetMember.username,
            "status": "pending",
            "duration_minutes": String(durationMinutes),
            "reason": reason ?? ""
        ]

        try await supabase.client
            .from("accountability_locks")
            .insert(lockInsert)
            .execute()

        try await postActivity(.lockRequested, description: "requested a focus lock for \(targetMember.username)")

        await fetchPendingLocks()
    }

    func respondToLock(_ lockId: UUID, approve: Bool) async throws {
        let newStatus = approve ? "approved" : "rejected"
        let expiresAt = approve ? Calendar.current.date(byAdding: .minute, value: pendingLocks.first { $0.id == lockId }?.durationMinutes ?? 30, to: Date()) : nil

        var update: [String: String] = ["status": newStatus]
        if let expires = expiresAt {
            update["expires_at"] = ISO8601DateFormatter().string(from: expires)
            update["status"] = "active"
        }

        try await supabase.client
            .from("accountability_locks")
            .update(update)
            .eq("id", value: lockId.uuidString)
            .execute()

        if approve {
            try await postActivity(.lockApproved, description: "accepted a focus lock")

            // Trigger enforcement - find the lock and notify
            if let lock = pendingLocks.first(where: { $0.id == lockId }) {
                let activeLock = AccountabilityLock(
                    id: lock.id,
                    familyGroupId: lock.familyGroupId,
                    requesterId: lock.requesterId,
                    requesterName: lock.requesterName,
                    targetUserId: lock.targetUserId,
                    targetUserName: lock.targetUserName,
                    status: .active,
                    durationMinutes: lock.durationMinutes,
                    reason: lock.reason,
                    createdAt: lock.createdAt,
                    expiresAt: expiresAt
                )
                onFamilyLockActivated?(activeLock)
            }
        }

        await fetchPendingLocks()
    }

    private func fetchPendingLocks() async {
        guard let group = familyGroup else { return }
        let userId = try? supabase.requireUserId()

        do {
            // Locks targeting current user that need response
            let pending: [AccountabilityLockRow] = try await supabase.client
                .from("accountability_locks")
                .select()
                .eq("family_group_id", value: group.id.uuidString)
                .eq("target_user_id", value: userId?.uuidString ?? "")
                .eq("status", value: "pending")
                .execute()
                .value

            pendingLocks = pending.map { $0.toLock() }

            // Active locks for current user
            let active: [AccountabilityLockRow] = try await supabase.client
                .from("accountability_locks")
                .select()
                .eq("family_group_id", value: group.id.uuidString)
                .eq("target_user_id", value: userId?.uuidString ?? "")
                .eq("status", value: "active")
                .execute()
                .value

            activeLocks = active.map { $0.toLock() }.filter { $0.isActive }
            
            // Check for and clean up any expired locks
            await checkExpiredLocks()
        } catch {
            self.error = error
        }
    }

    /// Check for expired locks and mark them as completed
    private func checkExpiredLocks() async {
        guard let group = familyGroup else { return }
        
        // Find locks that have expired but are still marked as active
        do {
            let expiredLocks: [AccountabilityLockRow] = try await supabase.client
                .from("accountability_locks")
                .select()
                .eq("family_group_id", value: group.id.uuidString)
                .eq("status", value: "active")
                .lt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
                .execute()
                .value
            
            // Mark each expired lock as completed
            for lock in expiredLocks {
                try await supabase.client
                    .from("accountability_locks")
                    .update(["status": "completed"])
                    .eq("id", value: lock.id.uuidString)
                    .execute()
            }
            
            // If any of these were our active locks, notify deactivation
            let userId = try? supabase.requireUserId()
            let ourExpiredLocks = expiredLocks.filter { $0.targetUserId == userId }
            if !ourExpiredLocks.isEmpty {
                activeLocks.removeAll { lock in
                    ourExpiredLocks.contains { $0.id == lock.id }
                }
                if activeLocks.isEmpty {
                    onFamilyLockDeactivated?()
                }
            }
        } catch {
            // Silently fail - this is a cleanup operation
        }
    }

    // MARK: - Activity Feed

    private func fetchActivityFeed() async {
        guard let group = familyGroup else { return }

        do {
            let activities: [FamilyActivityRow] = try await supabase.client
                .from("family_activities")
                .select()
                .eq("family_group_id", value: group.id.uuidString)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            activityFeed = activities.map { $0.toActivity() }
        } catch {
            self.error = error
        }
    }

    private func postActivity(_ type: FamilyActivity.ActivityType, description: String) async throws {
        guard let group = familyGroup else { return }
        let userId = try supabase.requireUserId()

        try await supabase.client
            .from("family_activities")
            .insert([
                "family_group_id": group.id.uuidString,
                "user_id": userId.uuidString,
                "username": currentMember?.username ?? "Someone",
                "activity_type": type.rawValue,
                "description": description
            ])
            .execute()
    }

    // Post session completion to family feed
    func notifySessionCompleted(durationMinutes: Int) async {
        guard isInFamily else { return }
        try? await postActivity(.sessionCompleted, description: "completed a \(durationMinutes)-minute focus session")
        await fetchActivityFeed()
    }

    // MARK: - Helpers

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}

// MARK: - Database Row Types

private struct FamilyGroupRow: Codable {
    let id: UUID
    let name: String
    let ownerId: UUID
    let ownerName: String
    let inviteCode: String
    let subscriptionId: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case ownerId = "owner_id"
        case ownerName = "owner_name"
        case inviteCode = "invite_code"
        case subscriptionId = "subscription_id"
        case createdAt = "created_at"
    }
}

private struct FamilyGroupInsert: Codable {
    let name: String
    let ownerId: UUID
    let ownerName: String
    let inviteCode: String

    enum CodingKeys: String, CodingKey {
        case name
        case ownerId = "owner_id"
        case ownerName = "owner_name"
        case inviteCode = "invite_code"
    }
}

private struct FamilyMemberRow: Codable {
    let id: UUID
    let familyGroupId: UUID
    let oderId: UUID
    let role: String
    let joinedAt: Date
    let familyGroup: FamilyGroupRow?
    let userStats: UserStatsInfo?

    enum CodingKeys: String, CodingKey {
        case id
        case familyGroupId = "family_group_id"
        case oderId = "user_id"
        case role
        case joinedAt = "joined_at"
        case familyGroup = "family_groups"
        case userStats = "user_stats"
    }

    func toMember() -> FamilyMember {
        FamilyMember(
            id: id,
            oderId: oderId,
            username: userStats?.username ?? "Anonymous",
            avatarURL: userStats?.avatarUrl,
            role: FamilyMember.MemberRole(rawValue: role) ?? .member,
            joinedAt: joinedAt,
            currentStreak: userStats?.currentStreak ?? 0,
            level: userStats?.level ?? 1,
            focusMinutesThisWeek: userStats?.totalFocusMinutes ?? 0,
            lastActiveAt: nil
        )
    }
}

private struct UserStatsInfo: Codable {
    let username: String?
    let avatarUrl: String?
    let level: Int
    let currentStreak: Int
    let totalFocusMinutes: Int

    enum CodingKeys: String, CodingKey {
        case username
        case avatarUrl = "avatar_url"
        case level
        case currentStreak = "current_streak"
        case totalFocusMinutes = "total_focus_minutes"
    }
}

private struct AccountabilityLockRow: Codable {
    let id: UUID
    let familyGroupId: UUID
    let requesterId: UUID
    let requesterName: String
    let targetUserId: UUID
    let targetUserName: String
    let status: String
    let durationMinutes: Int
    let reason: String?
    let createdAt: Date
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case familyGroupId = "family_group_id"
        case requesterId = "requester_id"
        case requesterName = "requester_name"
        case targetUserId = "target_user_id"
        case targetUserName = "target_user_name"
        case status
        case durationMinutes = "duration_minutes"
        case reason
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }

    func toLock() -> AccountabilityLock {
        AccountabilityLock(
            id: id,
            familyGroupId: familyGroupId,
            requesterId: requesterId,
            requesterName: requesterName,
            targetUserId: targetUserId,
            targetUserName: targetUserName,
            status: AccountabilityLock.LockStatus(rawValue: status) ?? .pending,
            durationMinutes: durationMinutes,
            reason: reason,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
    }
}

private struct FamilyActivityRow: Codable {
    let id: UUID
    let familyGroupId: UUID
    let oderId: UUID
    let username: String
    let activityType: String
    let description: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case familyGroupId = "family_group_id"
        case oderId = "user_id"
        case username
        case activityType = "activity_type"
        case description
        case createdAt = "created_at"
    }

    func toActivity() -> FamilyActivity {
        FamilyActivity(
            id: id,
            familyGroupId: familyGroupId,
            oderId: oderId,
            username: username,
            activityType: FamilyActivity.ActivityType(rawValue: activityType) ?? .sessionCompleted,
            description: description,
            createdAt: createdAt
        )
    }
}

// MARK: - Errors

enum FamilyError: LocalizedError {
    case groupNotFound
    case groupFull
    case alreadyInFamily
    case notAuthorized
    case memberNotFound

    var errorDescription: String? {
        switch self {
        case .groupNotFound: return "Family group not found. Check the invite code."
        case .groupFull: return "This family group is full (max 5 members)."
        case .alreadyInFamily: return "You're already in a family group."
        case .notAuthorized: return "You don't have permission to do this."
        case .memberNotFound: return "Member not found."
        }
    }
}
