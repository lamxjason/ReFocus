import Foundation
import Combine

/// Coordinates all sync managers - subscribes/unsubscribes based on authentication state
@MainActor
final class SyncCoordinator: ObservableObject {
    static let shared = SyncCoordinator()

    // MARK: - Published State

    @Published private(set) var isFullySynced: Bool = false
    @Published private(set) var syncStatus: SyncStatus = .disconnected

    enum SyncStatus: String {
        case disconnected = "Disconnected"
        case connecting = "Connecting..."
        case synced = "Synced"
        case error = "Sync Error"
    }

    // MARK: - Dependencies

    private let supabase = SupabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var syncTask: Task<Void, Never>?

    private init() {
        // Listen for auth state changes
        supabase.$isAuthenticated
            .removeDuplicates()
            .sink { [weak self] isAuthenticated in
                Task { @MainActor in
                    if isAuthenticated {
                        await self?.subscribeAll()
                    } else {
                        await self?.unsubscribeAll()
                    }
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        syncTask?.cancel()
        // Note: cancellables are automatically cleaned up when the object is deallocated
    }

    // MARK: - Subscribe All

    /// Subscribe all sync managers to realtime updates
    func subscribeAll() async {
        guard supabase.isAuthenticated else {
            syncStatus = .disconnected
            return
        }

        syncStatus = .connecting

        syncTask?.cancel()
        syncTask = Task {
            do {
                // Subscribe all managers in parallel
                async let websitesSub: () = WebsiteSyncManager.shared.subscribe()
                async let timerSub: () = TimerSyncManager.shared.subscribe()
                async let modesSub: () = FocusModeSyncManager.shared.subscribe()
                async let schedulesSub: () = ScheduleSyncManager.shared.subscribe()
                async let settingsSub: () = UserSettingsSyncManager.shared.subscribe()
                async let statsSub: () = UserStatsSyncManager.shared.subscribe()
                async let accountabilitySub: () = AccountabilityManager.shared.subscribe()

                // Wait for all subscriptions
                _ = try await (websitesSub, timerSub, modesSub, schedulesSub, settingsSub, statsSub, accountabilitySub)

                syncStatus = .synced
                isFullySynced = true

                Log.Sync.info("All managers subscribed successfully")

            } catch {
                Log.Sync.error("Subscription error", error: error)
                syncStatus = .error
                isFullySynced = false
            }
        }
    }

    /// Unsubscribe all sync managers
    func unsubscribeAll() async {
        syncTask?.cancel()
        syncTask = nil

        await WebsiteSyncManager.shared.unsubscribe()
        await TimerSyncManager.shared.unsubscribe()
        await FocusModeSyncManager.shared.unsubscribe()
        await ScheduleSyncManager.shared.unsubscribe()
        await UserSettingsSyncManager.shared.unsubscribe()
        await UserStatsSyncManager.shared.unsubscribe()
        await AccountabilityManager.shared.unsubscribe()

        syncStatus = .disconnected
        isFullySynced = false

        Log.Sync.info("All managers unsubscribed")
    }

    // MARK: - Manual Sync

    /// Force refresh all synced data
    func refreshAll() async {
        guard supabase.isAuthenticated else { return }

        // Refresh stats (calculated server-side)
        await UserStatsSyncManager.shared.refresh()
    }

    /// Push all local data to server (for initial sync)
    func pushAllLocalData() async throws {
        guard supabase.isAuthenticated else { return }

        try await FocusModeSyncManager.shared.pushAllModes()
        try await ScheduleSyncManager.shared.pushAllSchedules()

        Log.Sync.info("Pushed all local data to server")
    }
}
