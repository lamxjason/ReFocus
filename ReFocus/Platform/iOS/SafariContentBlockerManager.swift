import Foundation
#if os(iOS)
import SafariServices

/// Manages the Safari Content Blocker extension
/// Updates the blockerList.json and notifies Safari to reload rules
@MainActor
final class SafariContentBlockerManager: ObservableObject {
    static let shared = SafariContentBlockerManager()

    // MARK: - Constants

    private let appGroupIdentifier = "group.com.refocus.shared"
    private let blockerListFilename = "blockerList.json"
    private let contentBlockerIdentifier = "Zero.Re-Focus.ContentBlocker"

    // MARK: - Published State

    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var lastUpdateError: Error?
    @Published private(set) var blockedDomainCount: Int = 0

    // MARK: - Private

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private init() {
        checkBlockerStatus()
    }

    // MARK: - Public Methods

    /// Update the blocked domains list and notify Safari
    func updateBlockedDomains(_ domains: Set<String>) async {
        guard let containerURL = containerURL else {
            lastUpdateError = ContentBlockerError.appGroupNotFound
            return
        }

        let blockerListURL = containerURL.appendingPathComponent(blockerListFilename)

        // Generate the blocker rules JSON
        let rules = generateBlockerRules(for: domains)

        do {
            // Write the rules to the shared container
            let jsonData = try JSONSerialization.data(withJSONObject: rules, options: .prettyPrinted)
            try jsonData.write(to: blockerListURL, options: .atomic)

            blockedDomainCount = domains.count

            // Notify Safari to reload the content blocker
            try await reloadContentBlocker()

            isEnabled = true
            lastUpdateError = nil
        } catch {
            lastUpdateError = error
        }
    }

    /// Check if the content blocker is enabled in Safari settings
    func checkBlockerStatus() {
        Task {
            do {
                let state = try await SFContentBlockerManager.stateOfContentBlocker(
                    withIdentifier: contentBlockerIdentifier
                )
                isEnabled = state.isEnabled
            } catch {
                isEnabled = false
                lastUpdateError = error
            }
        }
    }

    /// Clear all blocked domains
    func clearBlockedDomains() async {
        await updateBlockedDomains([])
    }

    // MARK: - Private Methods

    private func generateBlockerRules(for domains: Set<String>) -> [[String: Any]] {
        guard !domains.isEmpty else {
            // Return a rule that matches nothing (effectively disabling blocking)
            return [
                [
                    "trigger": ["url-filter": "^$"],
                    "action": ["type": "block"]
                ]
            ]
        }

        return domains.map { domain in
            // Escape special regex characters in domain
            let escapedDomain = domain
                .replacingOccurrences(of: ".", with: "\\\\.")
                .replacingOccurrences(of: "-", with: "\\\\-")

            return [
                "trigger": [
                    "url-filter": ".*\\.\(escapedDomain)(/.*)?$|^\(escapedDomain)(/.*)?$",
                    "url-filter-is-case-sensitive": false,
                    "load-type": ["first-party", "third-party"]
                ],
                "action": [
                    "type": "block"
                ]
            ] as [String: Any]
        }
    }

    private func reloadContentBlocker() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            SFContentBlockerManager.reloadContentBlocker(
                withIdentifier: contentBlockerIdentifier
            ) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Errors

enum ContentBlockerError: LocalizedError {
    case appGroupNotFound
    case invalidRules

    var errorDescription: String? {
        switch self {
        case .appGroupNotFound:
            return "Could not access shared app group. Safari blocking may not work."
        case .invalidRules:
            return "Failed to generate valid blocking rules."
        }
    }
}
#endif
