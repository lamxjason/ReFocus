import Foundation
import Combine

/// Coordinates platform-specific blocking enforcement
/// Listens to TimerSyncManager and WebsiteSyncManager for state changes
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
        stopEnforcement()
    }

    private func handleTimerUpdated(_ state: SharedTimerState) {
        // Timer extended or modified, enforcement continues
        // Could update UI or logging here
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

        // If currently enforcing, the blocker will pick up the new list
    }

    var isMacAppBlockingEnabled: Bool {
        get { macAppBlocker.isEnabled }
        set { macAppBlocker.isEnabled = newValue }
    }
    #endif
}
