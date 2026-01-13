import Foundation
import Supabase
import Combine

/// Syncs user settings (strict mode, preferences) across devices via Supabase Realtime
@MainActor
final class UserSettingsSyncManager: ObservableObject {
    static let shared = UserSettingsSyncManager()

    // MARK: - Published State

    @Published private(set) var settings: UserSettings?
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var syncError: Error?
    @Published private(set) var lastSyncedAt: Date?

    // MARK: - Computed Properties

    var isStrictModeEnabled: Bool {
        settings?.isStrictModeEnabled ?? false
    }

    var minimumCommitmentMinutes: Int {
        settings?.minimumCommitmentMinutes ?? 5
    }

    var exitsUsedThisMonth: Int {
        settings?.exitsUsedThisMonth ?? 0
    }

    var weeklyGoalHours: Double {
        settings?.weeklyGoalHours ?? 10.0
    }

    // MARK: - Private

    private var realtimeChannel: RealtimeChannelV2?
    private let supabase = SupabaseManager.shared
    private static let localStorageKey = "localUserSettings"

    private init() {
        loadLocalSettings()
    }

    // MARK: - Subscription

    /// Subscribe to settings changes for the current user
    func subscribe() async throws {
        let userId = try supabase.requireUserId()

        // First, sync settings from server
        await syncFromServer(userId: userId)

        // Then subscribe to realtime changes
        let channel = supabase.client.realtimeV2.channel("user-settings-\(userId.uuidString)")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "user_settings",
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

    // MARK: - Settings Updates

    /// Toggle strict mode
    func setStrictModeEnabled(_ enabled: Bool) async throws {
        guard var currentSettings = settings else {
            // Create new settings if none exist
            try await createInitialSettings(strictModeEnabled: enabled)
            return
        }

        currentSettings.isStrictModeEnabled = enabled
        try await pushSettings(currentSettings)
    }

    /// Update minimum commitment
    func setMinimumCommitmentMinutes(_ minutes: Int) async throws {
        guard var currentSettings = settings else { return }

        currentSettings.minimumCommitmentMinutes = minutes
        try await pushSettings(currentSettings)
    }

    /// Increment exit counter (when user uses emergency exit)
    func recordExit() async throws {
        guard var currentSettings = settings else { return }

        // Reset counter if new month
        let now = Date()
        let calendar = Calendar.current
        if !calendar.isDate(currentSettings.monthStartDate, equalTo: now, toGranularity: .month) {
            currentSettings.monthStartDate = calendar.startOfMonth(for: now) ?? now
            currentSettings.exitsUsedThisMonth = 0
        }

        currentSettings.exitsUsedThisMonth += 1
        try await pushSettings(currentSettings)
    }

    /// Update weekly goal
    func setWeeklyGoalHours(_ hours: Double) async throws {
        guard var currentSettings = settings else { return }

        currentSettings.weeklyGoalHours = hours
        try await pushSettings(currentSettings)
    }

    // MARK: - Private Methods

    private func createInitialSettings(strictModeEnabled: Bool = false) async throws {
        guard let userId = supabase.currentUserId else { return }

        let newSettings = UserSettings(
            id: UUID(),
            userId: userId,
            isStrictModeEnabled: strictModeEnabled,
            minimumCommitmentMinutes: 5,
            exitsUsedThisMonth: 0,
            monthStartDate: Calendar.current.startOfMonth(for: Date()) ?? Date(),
            weeklyGoalHours: 10.0,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await supabase.client.from("user_settings")
            .insert(newSettings)
            .execute()

        settings = newSettings
        saveLocalSettings()
        lastSyncedAt = Date()
    }

    private func pushSettings(_ updatedSettings: UserSettings) async throws {
        var settingsToSave = updatedSettings
        settingsToSave.updatedAt = Date()

        try await supabase.client.from("user_settings")
            .update(settingsToSave)
            .eq("user_id", value: settingsToSave.userId.uuidString)
            .execute()

        settings = settingsToSave
        saveLocalSettings()
        lastSyncedAt = Date()
    }

    private func syncFromServer(userId: UUID) async {
        do {
            let response: [UserSettings] = try await supabase.client
                .from("user_settings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            if let serverSettings = response.first {
                settings = serverSettings
                saveLocalSettings()
            } else {
                // Create default settings if none exist on server
                try? await createInitialSettings()
            }

            lastSyncedAt = Date()
        } catch {
            syncError = error
            print("UserSettingsSyncManager: Failed to sync from server: \(error)")
            // Keep using local settings
        }
    }

    private func handleRealtimeChange(_ change: AnyAction) async {
        switch change {
        case .insert(let action):
            if let newSettings = try? action.decodeRecord(as: UserSettings.self, decoder: JSONDecoder()) {
                settings = newSettings
                saveLocalSettings()
            }

        case .update(let action):
            if let newSettings = try? action.decodeRecord(as: UserSettings.self, decoder: JSONDecoder()) {
                settings = newSettings
                saveLocalSettings()
            }

        case .delete:
            // Settings deleted - create new defaults
            try? await createInitialSettings()

        default:
            break
        }
    }

    // MARK: - Local Storage

    private func saveLocalSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Self.localStorageKey)
    }

    private func loadLocalSettings() {
        guard let data = UserDefaults.standard.data(forKey: Self.localStorageKey),
              let localSettings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return
        }
        settings = localSettings
    }
}

// MARK: - User Settings Model

struct UserSettings: Codable, Identifiable {
    var id: UUID
    var userId: UUID
    var isStrictModeEnabled: Bool
    var minimumCommitmentMinutes: Int
    var exitsUsedThisMonth: Int
    var monthStartDate: Date
    var weeklyGoalHours: Double
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case isStrictModeEnabled = "is_strict_mode_enabled"
        case minimumCommitmentMinutes = "minimum_commitment_minutes"
        case exitsUsedThisMonth = "exits_used_this_month"
        case monthStartDate = "month_start_date"
        case weeklyGoalHours = "weekly_goal_hours"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date? {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)
    }
}
