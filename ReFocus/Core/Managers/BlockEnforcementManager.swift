import Foundation
import Combine

/// Coordinates platform-specific blocking enforcement
/// Listens to TimerSyncManager and WebsiteSyncManager for state changes
/// Supports accountability partner mode with cross-device sync
@MainActor
final class BlockEnforcementManager: ObservableObject {
    static let shared = BlockEnforcementManager()

    // MARK: - Published State

    @Published private(set) var isEnforcing: Bool = false
    @Published private(set) var enforcementError: Error?

    // MARK: - Platform-Specific Enforcers

    #if os(iOS)
    @Published var localAppSelection: LocalAppSelection = .empty
    @Published private(set) var isScreenTimeAuthorized: Bool = false
    private let screenTimeEnforcer = iOSBlockEnforcer()
    #elseif os(macOS)
    private let macAppBlocker = MacAppBlocker.shared
    private let networkExtensionManager = NetworkExtensionManager.shared
    #endif

    // MARK: - Private

    private var timerSyncManager: TimerSyncManager { .shared }
    private var websiteSyncManager: WebsiteSyncManager { .shared }
    private var accountabilityManager: AccountabilityManager { .shared }
    private var familyManager: FamilyManager { .shared }
    private var notifications: NotificationManager { .shared }

    private init() {
        setupObservers()
        loadLocalState()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Listen to timer state changes
        timerSyncManager.onTimerActivated = { [weak self] state in
            Task { @MainActor in
                self?.handleTimerActivated(state)
            }
        }

        timerSyncManager.onTimerDeactivated = { [weak self] in
            Task { @MainActor in
                self?.handleTimerDeactivated()
            }
        }

        timerSyncManager.onTimerUpdated = { [weak self] state in
            Task { @MainActor in
                self?.handleTimerUpdated(state)
            }
        }

        // Listen to website changes
        websiteSyncManager.onWebsitesChanged = { [weak self] domains in
            Task { @MainActor in
                self?.handleWebsitesChanged(domains)
            }
        }

        // Listen to accountability state changes
        accountabilityManager.onAccountabilityActivated = { [weak self] in
            Task { @MainActor in
                self?.activateAccountability()
            }
        }

        accountabilityManager.onAccountabilityDeactivated = { [weak self] in
            Task { @MainActor in
                self?.deactivateAccountability()
            }
        }

        accountabilityManager.onUnlockApproved = { [weak self] _ in
            Task { @MainActor in
                self?.deactivateAccountability()
            }
        }

        // Listen to family plan lock changes
        familyManager.onFamilyLockActivated = { [weak self] lock in
            Task { @MainActor in
                self?.handleFamilyLockActivated(lock)
            }
        }

        familyManager.onFamilyLockDeactivated = { [weak self] in
            Task { @MainActor in
                self?.handleFamilyLockDeactivated()
            }
        }
    }

    private func loadLocalState() {
        #if os(iOS)
        localAppSelection = LocalAppSelection.load()
        screenTimeEnforcer.checkAuthorizationStatus()
        isScreenTimeAuthorized = screenTimeEnforcer.isAuthorized
        #endif
    }

    // MARK: - iOS Screen Time Authorization

    #if os(iOS)
    func requestScreenTimeAuthorization() async throws {
        try await screenTimeEnforcer.requestAuthorization()
        isScreenTimeAuthorized = screenTimeEnforcer.isAuthorized
    }

    func checkScreenTimeAuthorization() {
        screenTimeEnforcer.checkAuthorizationStatus()
        isScreenTimeAuthorized = screenTimeEnforcer.isAuthorized
    }
    #endif

    // MARK: - Timer Event Handlers

    private func handleTimerActivated(_ state: SharedTimerState) {
        startEnforcement()
    }

    private func handleTimerDeactivated() {
        // Only stop if no other blocking context is active
        if !isRegretPreventionActive && !isAccountabilityActive {
            stopEnforcement()
        }
    }

    private func handleTimerUpdated(_ state: SharedTimerState) {
        // Timer extended or modified, enforcement continues
    }

    private func handleWebsitesChanged(_ domains: Set<String>) {
        // Only update enforcement if currently enforcing
        guard isEnforcing else { return }

        #if os(iOS)
        screenTimeEnforcer.updateWebsites(domains)
        #elseif os(macOS)
        networkExtensionManager.updateBlockedDomains(domains)
        #endif
    }

    // MARK: - Enforcement Control

    func startEnforcement() {
        guard !isEnforcing else { return }

        let websites = websiteSyncManager.domains
        isEnforcing = true
        enforcementError = nil

        #if os(iOS)
        do {
            try screenTimeEnforcer.applyBlocks(
                apps: localAppSelection.selection,
                websites: websites
            )
        } catch {
            enforcementError = error
        }
        #elseif os(macOS)
        macAppBlocker.startBlocking()
        networkExtensionManager.enableFilter(domains: websites)
        #endif
    }

    func stopEnforcement() {
        guard isEnforcing else { return }

        isEnforcing = false

        #if os(iOS)
        screenTimeEnforcer.removeAllBlocks()
        #elseif os(macOS)
        macAppBlocker.stopBlocking()
        networkExtensionManager.disableFilter()
        #endif
    }

    // MARK: - iOS App Selection

    #if os(iOS)
    func updateAppSelection(_ selection: LocalAppSelection) {
        localAppSelection = selection
        selection.save()

        // If currently enforcing, update the blocks
        if isEnforcing {
            do {
                try screenTimeEnforcer.applyBlocks(
                    apps: selection.selection,
                    websites: websiteSyncManager.domains
                )
            } catch {
                enforcementError = error
            }
        }
    }
    #endif

    // MARK: - macOS App Selection

    #if os(macOS)
    func updateMacAppSelection(_ bundleIds: Set<String>) {
        macAppBlocker.blockedBundleIds = bundleIds
    }

    var isMacAppBlockingEnabled: Bool {
        get { macAppBlocker.isEnabled }
        set {
            macAppBlocker.isEnabled = newValue
            // Synchronize actual blocking state with the flag
            if newValue && isEnforcing {
                macAppBlocker.startBlocking()
            } else if !newValue {
                macAppBlocker.stopBlocking()
            }
        }
    }
    #endif

    // MARK: - Regret Prevention Integration

    @Published private(set) var isRegretPreventionActive: Bool = false

    func activateRegretPrevention() {
        guard !isRegretPreventionActive else { return }
        isRegretPreventionActive = true

        if !isEnforcing {
            startEnforcement()
        }
    }

    func deactivateRegretPrevention() {
        guard isRegretPreventionActive else { return }
        isRegretPreventionActive = false

        if !(timerSyncManager.timerState?.isActive ?? false) && !isAccountabilityActive {
            stopEnforcement()
        }
    }

    // MARK: - Accountability Partner Integration

    @Published private(set) var isAccountabilityActive: Bool = false
    @Published private(set) var isFamilyLockActive: Bool = false
    @Published private(set) var activeFamilyLock: AccountabilityLock?

    /// Activate accountability blocking (syncs across devices)
    func activateAccountability() {
        guard !isAccountabilityActive else { return }
        isAccountabilityActive = true

        #if os(iOS)
        // Apply accountability-specific blocks on iOS
        do {
            try screenTimeEnforcer.applyAccountabilityBlocks(apps: localAppSelection.selection)
        } catch {
            enforcementError = error
        }
        #elseif os(macOS)
        // On macOS, block websites when accountability is active
        // This ensures users can't bypass by using their Mac
        let websites = websiteSyncManager.domains
        networkExtensionManager.enableFilter(domains: websites)
        macAppBlocker.startBlocking()
        #endif

        if !isEnforcing {
            isEnforcing = true
        }
    }

    /// Deactivate accountability blocking (after partner approval)
    func deactivateAccountability() {
        guard isAccountabilityActive else { return }
        isAccountabilityActive = false

        #if os(iOS)
        screenTimeEnforcer.removeAccountabilityBlocks()
        #elseif os(macOS)
        // Only stop macOS blocking if no other context is active
        if !(timerSyncManager.timerState?.isActive ?? false) && !isRegretPreventionActive {
            networkExtensionManager.disableFilter()
            macAppBlocker.stopBlocking()
        }
        #endif

        // Only stop overall enforcement if nothing else is active
        if !(timerSyncManager.timerState?.isActive ?? false) && !isRegretPreventionActive {
            isEnforcing = false
        }
    }

    /// Check if any blocking context requires enforcement
    var hasActiveBlockingContext: Bool {
        (timerSyncManager.timerState?.isActive ?? false) ||
        isRegretPreventionActive ||
        isAccountabilityActive ||
        isFamilyLockActive
    }

    // MARK: - Family Plan Lock Integration

    /// Handle family lock activation
    private func handleFamilyLockActivated(_ lock: AccountabilityLock) {
        guard !isFamilyLockActive else { return }
        isFamilyLockActive = true
        activeFamilyLock = lock

        // Start enforcement if not already enforcing
        if !isEnforcing {
            startEnforcement()
        }

        // Schedule expiration check
        if let expiresAt = lock.expiresAt {
            scheduleFamilyLockExpiration(at: expiresAt)
        }
    }

    /// Handle family lock deactivation
    private func handleFamilyLockDeactivated() {
        guard isFamilyLockActive else { return }
        isFamilyLockActive = false
        activeFamilyLock = nil

        // Notify user the lock has ended
        Task {
            await notifications.notifyLockExpired()
        }

        // Only stop enforcement if no other context is active
        if !hasActiveBlockingContext {
            stopEnforcement()
        }
    }

    /// Schedule automatic deactivation when family lock expires
    private func scheduleFamilyLockExpiration(at date: Date) {
        let delay = max(0, date.timeIntervalSinceNow)
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if isFamilyLockActive, let lock = activeFamilyLock, lock.expiresAt ?? Date() <= Date() {
                handleFamilyLockDeactivated()
            }
        }
    }
}
