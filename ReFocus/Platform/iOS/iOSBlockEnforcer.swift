import Foundation

#if os(iOS)
import FamilyControls
import ManagedSettings

/// Named stores for different blocking contexts
/// Most restrictive setting wins when multiple stores have shields
extension ManagedSettingsStore.Name {
    /// Timer-based blocking (manual sessions)
    nonisolated(unsafe) static let timer = Self("timer")
    /// Schedule-based blocking (automatic schedules)
    nonisolated(unsafe) static let schedule = Self("schedule")
    /// Regret prevention blocking
    nonisolated(unsafe) static let regretPrevention = Self("regretPrevention")
    /// Hard mode blocking (most restrictive)
    nonisolated(unsafe) static let hardMode = Self("hardMode")
    /// Accountability partner blocking (requires partner approval to unlock)
    nonisolated(unsafe) static let accountability = Self("accountability")
}

/// Manages Screen Time API enforcement on iOS
/// Uses multiple named ManagedSettingsStores for context-specific blocking
@MainActor
final class iOSBlockEnforcer: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var authorizationError: Error?
    @Published private(set) var activeStores: Set<ManagedSettingsStore.Name> = []

    // MARK: - ManagedSettings (Named Stores)

    /// Default store for backward compatibility
    private let defaultStore = ManagedSettingsStore()

    /// Timer session store
    private let timerStore = ManagedSettingsStore(named: .timer)

    /// Schedule-based store
    private let scheduleStore = ManagedSettingsStore(named: .schedule)

    /// Regret prevention store
    private let regretPreventionStore = ManagedSettingsStore(named: .regretPrevention)

    /// Hard mode store (most restrictive)
    private let hardModeStore = ManagedSettingsStore(named: .hardMode)

    /// Accountability partner store
    private let accountabilityStore = ManagedSettingsStore(named: .accountability)

    init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Check current authorization status
    func checkAuthorizationStatus() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// Request Screen Time authorization
    func requestAuthorization() async throws {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
            authorizationError = nil
        } catch {
            authorizationError = error
            isAuthorized = false
            throw error
        }
    }

    // MARK: - Block Enforcement (Default Store - Backward Compatibility)

    /// Apply blocks for the selected apps and websites using default store
    func applyBlocks(apps: FamilyActivitySelection, websites: Set<String>) throws {
        try applyBlocks(apps: apps, websites: websites, to: .timer)
    }

    /// Remove all blocks from default store
    func removeAllBlocks() {
        removeBlocks(from: .timer)
    }

    /// Remove specific app blocks from default store
    func removeAppBlocks() {
        timerStore.shield.applications = nil
        timerStore.shield.applicationCategories = nil
        activeStores.remove(.timer)
    }

    /// Remove specific website blocks from default store
    func removeWebsiteBlocks() {
        timerStore.shield.webDomains = nil
    }

    // MARK: - Context-Specific Blocking

    /// Apply blocks to a specific named store
    func applyBlocks(apps: FamilyActivitySelection, websites: Set<String>, to storeName: ManagedSettingsStore.Name) throws {
        guard isAuthorized else {
            throw iOSBlockEnforcerError.notAuthorized
        }

        let store = getStore(for: storeName)

        // Apply app blocks
        if !apps.applicationTokens.isEmpty {
            store.shield.applications = apps.applicationTokens
        } else {
            store.shield.applications = nil
        }

        // Apply category blocks
        if !apps.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(apps.categoryTokens)
        } else {
            store.shield.applicationCategories = nil
        }

        // Apply website blocks from FamilyActivitySelection (device-specific tokens)
        if !apps.webDomainTokens.isEmpty {
            store.shield.webDomains = apps.webDomainTokens
        }

        activeStores.insert(storeName)
    }

    /// Remove blocks from a specific named store
    func removeBlocks(from storeName: ManagedSettingsStore.Name) {
        let store = getStore(for: storeName)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        activeStores.remove(storeName)
    }

    /// Apply schedule-based blocking
    func applyScheduleBlocks(apps: FamilyActivitySelection) throws {
        try applyBlocks(apps: apps, websites: [], to: .schedule)
    }

    /// Remove schedule blocks
    func removeScheduleBlocks() {
        removeBlocks(from: .schedule)
    }

    /// Apply regret prevention blocks
    func applyRegretPreventionBlocks(apps: FamilyActivitySelection) throws {
        try applyBlocks(apps: apps, websites: [], to: .regretPrevention)
    }

    /// Remove regret prevention blocks
    func removeRegretPreventionBlocks() {
        removeBlocks(from: .regretPrevention)
    }

    /// Apply hard mode blocks (most restrictive)
    func applyHardModeBlocks(apps: FamilyActivitySelection) throws {
        try applyBlocks(apps: apps, websites: [], to: .hardMode)
    }

    /// Remove hard mode blocks
    func removeHardModeBlocks() {
        removeBlocks(from: .hardMode)
    }

    // MARK: - Accountability Partner Blocking

    /// Apply accountability blocks (requires partner approval to remove)
    func applyAccountabilityBlocks(apps: FamilyActivitySelection) throws {
        try applyBlocks(apps: apps, websites: [], to: .accountability)
    }

    /// Remove accountability blocks (after partner approval)
    func removeAccountabilityBlocks() {
        removeBlocks(from: .accountability)
    }

    /// Remove all blocks from all stores
    func removeAllBlocksFromAllStores() {
        [timerStore, scheduleStore, regretPreventionStore, hardModeStore, accountabilityStore, defaultStore].forEach { store in
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil
        }
        activeStores.removeAll()
    }

    // MARK: - Website Sync (via Safari Content Blocker)

    /// Update website blocks (from synced list)
    /// - Note: This method is intentionally a no-op. Synced domain strings from Supabase
    ///   cannot be blocked via Screen Time API (which requires opaque FamilyActivitySelection tokens).
    ///   Instead, synced domains are blocked via the Safari Content Blocker extension.
    ///   See `SafariContentBlockerManager` for the actual implementation.
    func updateWebsites(_ domains: Set<String>) {
        // No-op: Safari Content Blocker extension handles synced domain blocking.
        // Screen Time API only works with device-specific FamilyActivitySelection tokens.
    }

    // MARK: - Helper Methods

    private func getStore(for name: ManagedSettingsStore.Name) -> ManagedSettingsStore {
        switch name {
        case .timer:
            return timerStore
        case .schedule:
            return scheduleStore
        case .regretPrevention:
            return regretPreventionStore
        case .hardMode:
            return hardModeStore
        case .accountability:
            return accountabilityStore
        default:
            return defaultStore
        }
    }

    /// Check if any store is currently enforcing
    var isAnyStoreActive: Bool {
        !activeStores.isEmpty
    }
}

// MARK: - Errors

enum iOSBlockEnforcerError: LocalizedError {
    case notAuthorized
    case tokenConversionFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Screen Time authorization is required to block apps and websites."
        case .tokenConversionFailed:
            return "Failed to convert website domains to block tokens."
        }
    }
}
#endif
