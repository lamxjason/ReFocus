import Foundation
import Supabase
import Combine

/// Syncs focus modes across devices via Supabase Realtime
/// App selections (FamilyActivitySelection) remain device-local
@MainActor
final class FocusModeSyncManager: ObservableObject {
    static let shared = FocusModeSyncManager()

    // MARK: - Published State

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var syncError: Error?
    @Published private(set) var lastSyncedAt: Date?

    // MARK: - Private

    private var realtimeChannel: RealtimeChannelV2?
    private let supabase = SupabaseManager.shared
    private var modeManager: FocusModeManager { FocusModeManager.shared }

    private init() {}

    // MARK: - Subscription

    /// Subscribe to mode changes for the current user
    func subscribe() async throws {
        let userId = try supabase.requireUserId()

        // First, sync modes from server
        await syncFromServer(userId: userId)

        // Then subscribe to realtime changes
        let channel = supabase.client.realtimeV2.channel("focus-modes-\(userId.uuidString)")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "focus_modes",
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

    /// Push a new mode to the server
    func pushMode(_ mode: FocusMode) async throws {
        guard let userId = supabase.currentUserId else { return }

        let record = FocusModeRecord(from: mode, userId: userId)

        try await supabase.client.from("focus_modes")
            .upsert(record, onConflict: "id")
            .execute()

        lastSyncedAt = Date()
    }

    /// Push updated mode to the server
    func updateMode(_ mode: FocusMode) async throws {
        guard let userId = supabase.currentUserId else { return }

        let record = FocusModeRecord(from: mode, userId: userId)

        try await supabase.client.from("focus_modes")
            .update(record)
            .eq("id", value: mode.id.uuidString)
            .execute()

        lastSyncedAt = Date()
    }

    /// Delete mode from server
    func deleteMode(_ mode: FocusMode) async throws {
        guard supabase.isAuthenticated else { return }

        try await supabase.client.from("focus_modes")
            .delete()
            .eq("id", value: mode.id.uuidString)
            .execute()

        lastSyncedAt = Date()
    }

    /// Full sync - push all local modes to server
    func pushAllModes() async throws {
        guard let userId = supabase.currentUserId else { return }

        let records = modeManager.modes.map { FocusModeRecord(from: $0, userId: userId) }

        for record in records {
            try await supabase.client.from("focus_modes")
                .upsert(record, onConflict: "id")
                .execute()
        }

        lastSyncedAt = Date()
    }

    // MARK: - Private Methods

    private func syncFromServer(userId: UUID) async {
        do {
            let response: [FocusModeRecord] = try await supabase.client
                .from("focus_modes")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value

            // Merge server modes with local (preserving local app selections)
            await mergeServerModes(response)
            lastSyncedAt = Date()
        } catch {
            syncError = error
            print("FocusModeSyncManager: Failed to sync from server: \(error)")
        }
    }

    private func mergeServerModes(_ serverRecords: [FocusModeRecord]) async {
        var localModes = modeManager.modes

        for record in serverRecords {
            if let localIndex = localModes.firstIndex(where: { $0.id == record.id }) {
                // Update existing mode, but preserve local app selection
                var updatedMode = record.toFocusMode()
                #if os(iOS)
                updatedMode.appSelectionData = localModes[localIndex].appSelectionData
                #endif
                modeManager.updateMode(updatedMode)
            } else {
                // New mode from server
                modeManager.addMode(record.toFocusMode())
            }
        }

        // Push local-only modes to server
        let serverIds = Set(serverRecords.map { $0.id })
        let localOnlyModes = localModes.filter { !serverIds.contains($0.id) }

        for mode in localOnlyModes {
            try? await pushMode(mode)
        }
    }

    private func handleRealtimeChange(_ change: AnyAction) async {
        switch change {
        case .insert(let action):
            if let record = try? action.decodeRecord(as: FocusModeRecord.self, decoder: JSONDecoder()) {
                // Only add if not already present
                if !modeManager.modes.contains(where: { $0.id == record.id }) {
                    modeManager.addMode(record.toFocusMode())
                }
            }

        case .update(let action):
            if let record = try? action.decodeRecord(as: FocusModeRecord.self, decoder: JSONDecoder()) {
                if let existingIndex = modeManager.modes.firstIndex(where: { $0.id == record.id }) {
                    var updatedMode = record.toFocusMode()
                    // Preserve local app selection
                    #if os(iOS)
                    updatedMode.appSelectionData = modeManager.modes[existingIndex].appSelectionData
                    #endif
                    modeManager.updateMode(updatedMode)
                }
            }

        case .delete(let action):
            let oldRecord = action.oldRecord
            if let idString = oldRecord["id"]?.stringValue,
               let id = UUID(uuidString: idString) {
                if let mode = modeManager.modes.first(where: { $0.id == id }) {
                    modeManager.deleteMode(mode)
                }
            }

        default:
            break
        }
    }
}

// MARK: - Database Record

/// Supabase row representation of FocusMode
struct FocusModeRecord: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let icon: String
    let color: String
    let durationSeconds: Int
    let isStrictMode: Bool
    let websiteDomains: [String]
    let themeGradientPrimary: String?
    let themeGradientSecondary: String?
    let createdAt: Date
    let lastUsedAt: Date?
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case icon
        case color
        case durationSeconds = "duration_seconds"
        case isStrictMode = "is_strict_mode"
        case websiteDomains = "website_domains"
        case themeGradientPrimary = "theme_gradient_primary"
        case themeGradientSecondary = "theme_gradient_secondary"
        case createdAt = "created_at"
        case lastUsedAt = "last_used_at"
        case deviceId = "device_id"
    }

    init(from mode: FocusMode, userId: UUID) {
        self.id = mode.id
        self.userId = userId
        self.name = mode.name
        self.icon = mode.icon
        self.color = mode.color
        self.durationSeconds = Int(mode.duration)
        self.isStrictMode = mode.isStrictMode
        self.websiteDomains = mode.websiteDomains
        self.themeGradientPrimary = mode.themeGradient?.primaryHex
        self.themeGradientSecondary = mode.themeGradient?.secondaryHex
        self.createdAt = mode.createdAt
        self.lastUsedAt = mode.lastUsedAt
        self.deviceId = DeviceInfo.currentDeviceId
    }

    func toFocusMode() -> FocusMode {
        var mode = FocusMode(
            id: id,
            name: name,
            icon: icon,
            color: color,
            themeGradient: themeGradientPrimary.flatMap { ThemeGradient.from(hex: $0) },
            duration: TimeInterval(durationSeconds),
            isStrictMode: isStrictMode,
            websiteDomains: websiteDomains
        )
        // Note: createdAt and lastUsedAt are set in init, we need to override
        // This is a limitation - the struct doesn't expose setters for these
        return mode
    }
}
