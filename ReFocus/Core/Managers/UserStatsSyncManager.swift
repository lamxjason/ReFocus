import Foundation
import Supabase
import Combine

/// Syncs user stats (XP, level, streaks) across devices via Supabase Realtime
/// Stats are calculated server-side from focus_sessions table
@MainActor
final class UserStatsSyncManager: ObservableObject {
    static let shared = UserStatsSyncManager()

    // MARK: - Published State

    @Published private(set) var stats: UserStats?
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var syncError: Error?
    @Published private(set) var lastSyncedAt: Date?

    // MARK: - Computed Properties

    var totalXP: Int { stats?.totalXP ?? 0 }
    var currentLevel: Int { stats?.currentLevel ?? 1 }
    var currentStreak: Int { stats?.currentStreak ?? 0 }
    var longestStreak: Int { stats?.longestStreak ?? 0 }
    var totalFocusSeconds: Int { stats?.totalFocusSeconds ?? 0 }
    var totalSessions: Int { stats?.totalSessions ?? 0 }
    var completedSessions: Int { stats?.completedSessions ?? 0 }

    /// XP needed for next level
    var xpToNextLevel: Int {
        let currentLevelXP = (currentLevel - 1) * 1000
        let nextLevelXP = currentLevel * 1000
        return nextLevelXP - totalXP
    }

    /// Progress to next level (0.0 - 1.0)
    var levelProgress: Double {
        let xpInCurrentLevel = totalXP % 1000
        return Double(xpInCurrentLevel) / 1000.0
    }

    /// Formatted total focus time
    var totalFocusTimeFormatted: String {
        let hours = totalFocusSeconds / 3600
        let minutes = (totalFocusSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Private

    private var realtimeChannel: RealtimeChannelV2?
    private let supabase = SupabaseManager.shared
    private static let localStorageKey = "localUserStats"

    private init() {
        loadLocalStats()
    }

    // MARK: - Subscription

    /// Subscribe to stats changes for the current user
    func subscribe() async throws {
        let userId = try supabase.requireUserId()

        // First, sync stats from server
        await syncFromServer(userId: userId)

        // Then subscribe to realtime changes
        let channel = supabase.client.realtimeV2.channel("user-stats-\(userId.uuidString)")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "user_stats",
            filter: "user_id=eq.\(userId.uuidString)"
        )

        await channel.subscribe()

        Task {
            for await change in changes {
                await handleRealtimeChange(change)
            }
        }

        realtimeChannel = channel
        isConnected = true
    }

    /// Unsubscribe from realtime updates
    func unsubscribe() async {
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil
        isConnected = false
    }

    // MARK: - Manual Refresh

    /// Force refresh stats from server
    func refresh() async {
        guard let userId = supabase.currentUserId else { return }
        await syncFromServer(userId: userId)
    }

    // MARK: - Private Methods

    private func syncFromServer(userId: UUID) async {
        do {
            let response: [UserStats] = try await supabase.client
                .from("user_stats")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            if let serverStats = response.first {
                stats = serverStats
                saveLocalStats()
            } else {
                // Initialize stats if none exist (will be created by trigger on first session)
                stats = UserStats(
                    id: UUID(),
                    userId: userId,
                    totalXP: 0,
                    currentLevel: 1,
                    currentStreak: 0,
                    longestStreak: 0,
                    lastSessionDate: nil,
                    totalFocusSeconds: 0,
                    totalSessions: 0,
                    completedSessions: 0,
                    updatedAt: Date()
                )
            }

            lastSyncedAt = Date()
        } catch {
            syncError = error
            print("UserStatsSyncManager: Failed to sync from server: \(error)")
            // Keep using local stats
        }
    }

    private func handleRealtimeChange(_ change: AnyAction) async {
        switch change {
        case .insert(let action):
            if let newStats = try? action.decodeRecord(as: UserStats.self, decoder: JSONDecoder()) {
                stats = newStats
                saveLocalStats()
            }

        case .update(let action):
            if let newStats = try? action.decodeRecord(as: UserStats.self, decoder: JSONDecoder()) {
                stats = newStats
                saveLocalStats()
            }

        default:
            break
        }
    }

    // MARK: - Local Storage

    private func saveLocalStats() {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        UserDefaults.standard.set(data, forKey: Self.localStorageKey)
    }

    private func loadLocalStats() {
        guard let data = UserDefaults.standard.data(forKey: Self.localStorageKey),
              let localStats = try? JSONDecoder().decode(UserStats.self, from: data) else {
            return
        }
        stats = localStats
    }
}

// MARK: - User Stats Model

struct UserStats: Codable, Identifiable {
    var id: UUID
    var userId: UUID
    var totalXP: Int
    var currentLevel: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastSessionDate: Date?
    var totalFocusSeconds: Int
    var totalSessions: Int
    var completedSessions: Int
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case totalXP = "total_xp"
        case currentLevel = "current_level"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastSessionDate = "last_session_date"
        case totalFocusSeconds = "total_focus_seconds"
        case totalSessions = "total_sessions"
        case completedSessions = "completed_sessions"
        case updatedAt = "updated_at"
    }
}
