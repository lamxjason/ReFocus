import Foundation

#if os(macOS)
import NetworkExtension

/// Manages the Network Extension for website blocking on macOS
/// Requires com.apple.developer.networking.networkextension entitlement
@MainActor
final class NetworkExtensionManager: ObservableObject {
    static let shared = NetworkExtensionManager()

    // MARK: - Published State

    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var status: String = "Not Configured"
    @Published private(set) var error: Error?

    // MARK: - App Group for sharing data with extension

    private static let appGroupId = "group.com.refocus.shared"
    private static let blockedDomainsKey = "blockedDomains"

    private var filterManager: NEFilterManager {
        NEFilterManager.shared()
    }

    private init() {
        Task {
            await loadFilterConfiguration()
        }
    }

    // MARK: - Configuration

    /// Load current filter configuration
    func loadFilterConfiguration() async {
        do {
            try await filterManager.loadFromPreferences()
            updateStatus()
        } catch {
            self.error = error
            status = "Error: \(error.localizedDescription)"
        }
    }

    /// Enable the content filter with the given blocked domains
    func enableFilter(domains: Set<String>) {
        // Save domains to App Group UserDefaults for the extension to read
        saveDomainsToAppGroup(domains)

        // Configure and enable the filter
        Task {
            do {
                try await filterManager.loadFromPreferences()

                // Configure the filter
                let filterConfig = NEFilterProviderConfiguration()
                filterConfig.filterBrowsers = true
                filterConfig.filterSockets = false

                filterManager.providerConfiguration = filterConfig
                filterManager.isEnabled = true

                try await filterManager.saveToPreferences()

                isEnabled = true
                updateStatus()
            } catch {
                self.error = error
                status = "Failed to enable: \(error.localizedDescription)"
            }
        }
    }

    /// Disable the content filter
    func disableFilter() {
        Task {
            do {
                try await filterManager.loadFromPreferences()
                filterManager.isEnabled = false
                try await filterManager.saveToPreferences()

                isEnabled = false
                updateStatus()
            } catch {
                self.error = error
            }
        }
    }

    /// Update the blocked domains list
    func updateBlockedDomains(_ domains: Set<String>) {
        saveDomainsToAppGroup(domains)

        // The extension will pick up the new domains on next filter evaluation
        // Optionally, we could reload the extension here
    }

    // MARK: - Private Methods

    private func saveDomainsToAppGroup(_ domains: Set<String>) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId) else {
            error = NetworkExtensionError.appGroupNotAvailable
            return
        }

        defaults.set(Array(domains), forKey: Self.blockedDomainsKey)
    }

    private func updateStatus() {
        if filterManager.isEnabled {
            status = "Active"
            isEnabled = true
        } else {
            status = "Inactive"
            isEnabled = false
        }
    }
}

// MARK: - Errors

enum NetworkExtensionError: LocalizedError {
    case appGroupNotAvailable
    case configurationFailed
    case entitlementMissing

    var errorDescription: String? {
        switch self {
        case .appGroupNotAvailable:
            return "App Group is not available. Check your entitlements."
        case .configurationFailed:
            return "Failed to configure the network filter."
        case .entitlementMissing:
            return "Network Extension entitlement is required. Apply at developer.apple.com."
        }
    }
}
#endif
