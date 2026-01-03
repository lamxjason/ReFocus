import Foundation

#if os(iOS)
import FamilyControls
import ManagedSettings

/// Manages Screen Time API enforcement on iOS
/// Uses ManagedSettingsStore to apply and remove blocks
@MainActor
final class iOSBlockEnforcer: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var authorizationError: Error?

    // MARK: - ManagedSettings

    private let store = ManagedSettingsStore()

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

    // MARK: - Block Enforcement

    /// Apply blocks for the selected apps and websites
    func applyBlocks(apps: FamilyActivitySelection, websites: Set<String>) throws {
        guard isAuthorized else {
            throw iOSBlockEnforcerError.notAuthorized
        }

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

        // Note: Website domain strings from Supabase cannot be directly converted
        // to WebDomainTokens. The Screen Time API requires tokens from
        // FamilyActivitySelection. For synced website blocking, consider:
        // 1. Using a VPN-based content filter
        // 2. Using Safari Content Blocker
        // 3. Relying on FamilyActivitySelection for both apps and websites
    }

    /// Update website blocks (from synced list)
    func updateWebsites(_ domains: Set<String>) {
        // Note: Screen Time API cannot block arbitrary domain strings
        // WebDomainTokens must come from FamilyActivitySelection
        // This method is a placeholder for future implementation
        // using alternative blocking mechanisms
    }

    /// Remove all blocks
    func removeAllBlocks() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    /// Remove specific app blocks
    func removeAppBlocks() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    /// Remove specific website blocks
    func removeWebsiteBlocks() {
        store.shield.webDomains = nil
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
