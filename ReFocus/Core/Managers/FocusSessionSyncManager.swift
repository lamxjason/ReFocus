import Foundation
import Supabase

/// Manages syncing focus sessions to Supabase for cross-device stats
@MainActor
final class FocusSessionSyncManager: ObservableObject {
    static let shared = FocusSessionSyncManager()

    // MARK: - Published State

    @Published private(set) var syncedSessions: [FocusSession] = []
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncError: String?

    // MARK: - Private

    private let supabase = SupabaseManager.shared
    private let tableName = "focus_sessions"

    private init() {}

    // MARK: - Save Session

    /// Save a completed focus session to Supabase
    func saveSession(_ session: FocusSession) async {
        guard supabase.isAuthenticated else {
            // Not authenticated, session will only be stored locally
            return
        }

        do {
            try await supabase.client.from(tableName)
                .insert(session)
                .execute()

            // Add to local cache
            syncedSessions.insert(session, at: 0)
            lastSyncError = nil
        } catch {
            lastSyncError = "Failed to sync session: \(error.localizedDescription)"
            print("FocusSessionSyncManager: Failed to save session - \(error)")
        }
    }

    /// Create and save a new session when a focus session completes
    func recordCompletedSession(
        plannedDuration: TimeInterval,
        actualDuration: TimeInterval,
        wasCompleted: Bool,
        blockedWebsites: [String],
        blockedAppCount: Int,
        modeName: String?
    ) async {
        guard supabase.isAuthenticated,
              let userId = try? supabase.requireUserId() else {
            return
        }

        let session = FocusSession(
            userId: userId,
            deviceId: DeviceInfo.currentDeviceId,
            startTime: Date().addingTimeInterval(-actualDuration),
            endTime: Date(),
            plannedDurationSeconds: Int(plannedDuration),
            actualDurationSeconds: Int(actualDuration),
            wasCompleted: wasCompleted,
            blockedWebsiteCount: blockedWebsites.count,
            blockedAppCount: blockedAppCount,
            blockedWebsites: blockedWebsites,
            modeName: modeName
        )

        await saveSession(session)
    }

    // MARK: - Fetch Sessions

    /// Fetch all sessions for the current user (across all devices)
    func fetchAllSessions() async {
        guard supabase.isAuthenticated else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let userId = try supabase.requireUserId()

            let sessions: [FocusSession] = try await supabase.client
                .from(tableName)
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("start_time", ascending: false)
                .limit(500) // Limit to recent 500 sessions
                .execute()
                .value

            syncedSessions = sessions
            lastSyncError = nil
        } catch {
            lastSyncError = "Failed to fetch sessions: \(error.localizedDescription)"
            print("FocusSessionSyncManager: Failed to fetch sessions - \(error)")
        }
    }

    /// Fetch sessions within a date range
    func fetchSessions(from startDate: Date, to endDate: Date) async -> [FocusSession] {
        guard supabase.isAuthenticated else { return [] }

        do {
            let userId = try supabase.requireUserId()
            let formatter = ISO8601DateFormatter()

            let sessions: [FocusSession] = try await supabase.client
                .from(tableName)
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("start_time", value: formatter.string(from: startDate))
                .lte("start_time", value: formatter.string(from: endDate))
                .order("start_time", ascending: false)
                .execute()
                .value

            return sessions
        } catch {
            print("FocusSessionSyncManager: Failed to fetch sessions in range - \(error)")
            return []
        }
    }

    /// Fetch sessions for today
    func fetchTodaysSessions() async -> [FocusSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

        return await fetchSessions(from: startOfDay, to: endOfDay)
    }

    /// Fetch sessions for this week
    func fetchThisWeeksSessions() async -> [FocusSession] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return []
        }

        return await fetchSessions(from: weekStart, to: weekEnd)
    }

    // MARK: - Stats Aggregation

    /// Get total focus time across all synced sessions
    var totalFocusTime: TimeInterval {
        syncedSessions.reduce(0) { $0 + $1.duration }
    }

    /// Get total focus time for today
    func todaysFocusTime() -> TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return syncedSessions
            .filter { calendar.isDate($0.startTime, inSameDayAs: today) }
            .reduce(0) { $0 + $1.duration }
    }

    /// Get total focus time for this week
    func thisWeeksFocusTime() -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()

        return syncedSessions
            .filter { calendar.isDate($0.startTime, equalTo: now, toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.duration }
    }

    /// Get sessions grouped by device
    func sessionsByDevice() -> [String: [FocusSession]] {
        Dictionary(grouping: syncedSessions, by: { $0.deviceId })
    }

    /// Get focus time by device
    func focusTimeByDevice() -> [String: TimeInterval] {
        var result: [String: TimeInterval] = [:]

        for (deviceId, sessions) in sessionsByDevice() {
            result[deviceId] = sessions.reduce(0) { $0 + $1.duration }
        }

        return result
    }

    /// Get completion rate (sessions completed vs started)
    var completionRate: Double {
        guard !syncedSessions.isEmpty else { return 0 }
        let completed = syncedSessions.filter { $0.wasCompleted }.count
        return Double(completed) / Double(syncedSessions.count)
    }

    /// Get average session duration
    var averageSessionDuration: TimeInterval {
        guard !syncedSessions.isEmpty else { return 0 }
        return totalFocusTime / Double(syncedSessions.count)
    }
}
