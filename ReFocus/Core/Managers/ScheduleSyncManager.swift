import Foundation
import Supabase
import Combine

/// Syncs focus schedules across devices via Supabase Realtime
/// App selections remain device-local (FamilyActivitySelection is device-specific)
@MainActor
final class ScheduleSyncManager: ObservableObject {
    static let shared = ScheduleSyncManager()

    // MARK: - Published State

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var syncError: Error?
    @Published private(set) var lastSyncedAt: Date?

    // MARK: - Private

    private var realtimeChannel: RealtimeChannelV2?
    private let supabase = SupabaseManager.shared
    private var scheduleManager: ScheduleManager { ScheduleManager.shared }

    private init() {}

    // MARK: - Subscription

    /// Subscribe to schedule changes for the current user
    func subscribe() async throws {
        let userId = try supabase.requireUserId()

        // First, sync schedules from server
        await syncFromServer(userId: userId)

        // Then subscribe to realtime changes
        let channel = supabase.client.realtimeV2.channel("focus-schedules-\(userId.uuidString)")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "focus_schedules",
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

    // MARK: - Sync Operations

    /// Push a new schedule to the server
    func pushSchedule(_ schedule: FocusSchedule) async throws {
        guard let userId = supabase.currentUserId else { return }

        let record = FocusScheduleRecord(from: schedule, userId: userId)

        try await supabase.client.from("focus_schedules")
            .upsert(record, onConflict: "id")
            .execute()

        lastSyncedAt = Date()
    }

    /// Push updated schedule to the server
    func updateSchedule(_ schedule: FocusSchedule) async throws {
        guard let userId = supabase.currentUserId else { return }

        let record = FocusScheduleRecord(from: schedule, userId: userId)

        try await supabase.client.from("focus_schedules")
            .update(record)
            .eq("id", value: schedule.id.uuidString)
            .execute()

        lastSyncedAt = Date()
    }

    /// Delete schedule from server
    func deleteSchedule(_ schedule: FocusSchedule) async throws {
        guard supabase.isAuthenticated else { return }

        try await supabase.client.from("focus_schedules")
            .delete()
            .eq("id", value: schedule.id.uuidString)
            .execute()

        lastSyncedAt = Date()
    }

    /// Full sync - push all local schedules to server
    func pushAllSchedules() async throws {
        guard let userId = supabase.currentUserId else { return }

        let records = scheduleManager.schedules.map { FocusScheduleRecord(from: $0, userId: userId) }

        for record in records {
            try await supabase.client.from("focus_schedules")
                .upsert(record, onConflict: "id")
                .execute()
        }

        lastSyncedAt = Date()
    }

    // MARK: - Private Methods

    private func syncFromServer(userId: UUID) async {
        do {
            let response: [FocusScheduleRecord] = try await supabase.client
                .from("focus_schedules")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value

            // Merge server schedules with local (preserving local app selections)
            await mergeServerSchedules(response)
            lastSyncedAt = Date()
        } catch {
            syncError = error
            print("ScheduleSyncManager: Failed to sync from server: \(error)")
        }
    }

    private func mergeServerSchedules(_ serverRecords: [FocusScheduleRecord]) async {
        let localSchedules = scheduleManager.schedules

        for record in serverRecords {
            if let localIndex = localSchedules.firstIndex(where: { $0.id == record.id }) {
                // Update existing schedule, but preserve local app selection
                var updatedSchedule = record.toFocusSchedule()
                updatedSchedule.appSelectionData = localSchedules[localIndex].appSelectionData
                scheduleManager.updateSchedule(updatedSchedule)
            } else {
                // New schedule from server
                scheduleManager.addSchedule(record.toFocusSchedule())
            }
        }

        // Push local-only schedules to server
        let serverIds = Set(serverRecords.map { $0.id })
        let localOnlySchedules = localSchedules.filter { !serverIds.contains($0.id) }

        for schedule in localOnlySchedules {
            try? await pushSchedule(schedule)
        }
    }

    private func handleRealtimeChange(_ change: AnyAction) async {
        switch change {
        case .insert(let action):
            if let record = try? action.decodeRecord(as: FocusScheduleRecord.self, decoder: JSONDecoder()) {
                // Only add if not already present
                if !scheduleManager.schedules.contains(where: { $0.id == record.id }) {
                    scheduleManager.addSchedule(record.toFocusSchedule())
                }
            }

        case .update(let action):
            if let record = try? action.decodeRecord(as: FocusScheduleRecord.self, decoder: JSONDecoder()) {
                if let existingIndex = scheduleManager.schedules.firstIndex(where: { $0.id == record.id }) {
                    var updatedSchedule = record.toFocusSchedule()
                    // Preserve local app selection
                    updatedSchedule.appSelectionData = scheduleManager.schedules[existingIndex].appSelectionData
                    scheduleManager.updateSchedule(updatedSchedule)
                }
            }

        case .delete(let action):
            let oldRecord = action.oldRecord
            if let idString = oldRecord["id"]?.stringValue,
               let id = UUID(uuidString: idString) {
                scheduleManager.deleteSchedule(id: id)
            }

        default:
            break
        }
    }
}

// MARK: - Database Record

/// Supabase row representation of FocusSchedule
struct FocusScheduleRecord: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
    let days: [Int] // Weekday raw values
    let isEnabled: Bool
    let isStrictMode: Bool
    let focusModeId: UUID?
    let websiteDomains: [String]
    let themeGradientPrimary: String?
    let themeGradientSecondary: String?
    let createdAt: Date
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case startHour = "start_hour"
        case startMinute = "start_minute"
        case endHour = "end_hour"
        case endMinute = "end_minute"
        case days
        case isEnabled = "is_enabled"
        case isStrictMode = "is_strict_mode"
        case focusModeId = "focus_mode_id"
        case websiteDomains = "website_domains"
        case themeGradientPrimary = "theme_gradient_primary"
        case themeGradientSecondary = "theme_gradient_secondary"
        case createdAt = "created_at"
        case deviceId = "device_id"
    }

    init(from schedule: FocusSchedule, userId: UUID) {
        self.id = schedule.id
        self.userId = userId
        self.name = schedule.name
        self.startHour = schedule.startTime.hour
        self.startMinute = schedule.startTime.minute
        self.endHour = schedule.endTime.hour
        self.endMinute = schedule.endTime.minute
        self.days = schedule.days.map { $0.rawValue }
        self.isEnabled = schedule.isEnabled
        self.isStrictMode = schedule.isStrictMode
        self.focusModeId = schedule.focusModeId
        self.websiteDomains = schedule.websiteDomains
        self.themeGradientPrimary = schedule.themeGradient.primaryHex
        self.themeGradientSecondary = schedule.themeGradient.secondaryHex
        self.createdAt = Date()
        self.deviceId = DeviceInfo.currentDeviceId
    }

    func toFocusSchedule() -> FocusSchedule {
        let weekdays = Set(days.compactMap { Weekday(rawValue: $0) })
        let gradient = themeGradientPrimary.flatMap { ThemeGradient.from(hex: $0) } ?? .violet

        return FocusSchedule(
            id: id,
            name: name,
            startTime: TimeComponents(hour: startHour, minute: startMinute),
            endTime: TimeComponents(hour: endHour, minute: endMinute),
            days: weekdays,
            isEnabled: isEnabled,
            isStrictMode: isStrictMode,
            focusModeId: focusModeId,
            themeGradient: gradient,
            appSelectionData: nil, // Device-specific, not synced
            websiteDomains: websiteDomains
        )
    }
}
