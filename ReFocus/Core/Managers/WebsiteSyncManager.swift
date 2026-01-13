import Foundation
import Supabase
import Combine

/// Manages real-time website list synchronization via Supabase Realtime
/// Falls back to local storage when offline
@MainActor
final class WebsiteSyncManager: ObservableObject {
    static let shared = WebsiteSyncManager()

    // MARK: - Published State

    @Published private(set) var blockedWebsites: [BlockedWebsite] = []
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var syncError: Error?

    // MARK: - Callbacks

    var onWebsitesChanged: ((Set<String>) -> Void)?

    // MARK: - Private

    private var realtimeChannel: RealtimeChannelV2?
    private let supabase = SupabaseManager.shared
    private static let localStorageKey = "localBlockedWebsites"

    private init() {
        // Load local websites on init
        loadLocalWebsites()
    }

    // MARK: - Computed Properties

    /// Set of all blocked domain strings
    var domains: Set<String> {
        blockedWebsites.domains
    }

    // MARK: - Subscription

    /// Subscribe to website list changes for the current user
    func subscribe() async throws {
        let userId = try supabase.requireUserId()

        // First, fetch current websites
        await fetchWebsites(userId: userId)

        // Then subscribe to realtime changes
        let channel = supabase.client.realtimeV2.channel("websites-\(userId.uuidString)")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "blocked_websites",
            filter: "user_id=eq.\(userId.uuidString)"
        )

        await channel.subscribe()

        Task {
            for await change in changes {
                await handleRealtimeChange(change, userId: userId)
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

    // MARK: - CRUD Operations

    /// Add a website to the blocked list
    func addWebsite(_ domain: String) async throws {
        let normalizedDomain = BlockedWebsite.normalizeDomain(domain)

        // Check if already exists
        guard !blockedWebsites.contains(where: { $0.domain == normalizedDomain }) else {
            return
        }

        // Try to add to Supabase if authenticated
        if let userId = supabase.currentUserId {
            let website = BlockedWebsite(userId: userId, domain: normalizedDomain)

            do {
                try await supabase.client.from("blocked_websites")
                    .insert(website)
                    .execute()

                // Optimistic update
                blockedWebsites.append(website)
            } catch {
                // Fall back to local storage
                let localWebsite = BlockedWebsite(userId: userId, domain: normalizedDomain)
                blockedWebsites.append(localWebsite)
                saveLocalWebsites()
            }
        } else {
            // Local-only storage
            let localWebsite = BlockedWebsite(userId: UUID(), domain: normalizedDomain)
            blockedWebsites.append(localWebsite)
            saveLocalWebsites()
        }

        notifyWebsitesChanged()
    }

    /// Add website without throwing (for convenience)
    @discardableResult
    func addWebsiteLocal(_ domain: String) -> BlockedWebsite? {
        let normalizedDomain = BlockedWebsite.normalizeDomain(domain)

        guard !blockedWebsites.contains(where: { $0.domain == normalizedDomain }) else {
            return nil
        }

        let website = BlockedWebsite(userId: supabase.currentUserId ?? UUID(), domain: normalizedDomain)
        blockedWebsites.insert(website, at: 0) // Insert at top for better UX
        saveLocalWebsites()
        notifyWebsitesChanged()
        return website
    }

    /// Remove a website from the blocked list
    func removeWebsite(_ website: BlockedWebsite) async throws {
        // Try to delete from Supabase
        if supabase.isAuthenticated {
            do {
                try await supabase.client.from("blocked_websites")
                    .delete()
                    .eq("id", value: website.id.uuidString)
                    .execute()
            } catch {
                // Continue with local removal even if sync fails
                print("Sync delete failed: \(error)")
            }
        }

        // Local update
        blockedWebsites.removeAll { $0.id == website.id }
        saveLocalWebsites()
        notifyWebsitesChanged()
    }

    /// Remove website without throwing
    func removeWebsiteLocal(_ website: BlockedWebsite) {
        blockedWebsites.removeAll { $0.id == website.id }
        saveLocalWebsites()
        notifyWebsitesChanged()
    }

    /// Remove a website by domain string
    func removeWebsite(domain: String) async throws {
        let normalizedDomain = BlockedWebsite.normalizeDomain(domain)

        guard let website = blockedWebsites.first(where: { $0.domain == normalizedDomain }) else {
            return
        }

        try await removeWebsite(website)
    }

    /// Fetch all websites (manual refresh)
    func fetchWebsites() async throws {
        let userId = try supabase.requireUserId()
        await fetchWebsites(userId: userId)
    }

    // MARK: - Local Storage

    private func saveLocalWebsites() {
        guard let data = try? JSONEncoder().encode(blockedWebsites) else { return }
        UserDefaults.standard.set(data, forKey: Self.localStorageKey)
    }

    private func loadLocalWebsites() {
        guard let data = UserDefaults.standard.data(forKey: Self.localStorageKey),
              let websites = try? JSONDecoder().decode([BlockedWebsite].self, from: data) else {
            return
        }
        blockedWebsites = websites
        notifyWebsitesChanged()
    }

    // MARK: - Private Methods

    private func fetchWebsites(userId: UUID) async {
        do {
            let response: [BlockedWebsite] = try await supabase.client
                .from("blocked_websites")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            blockedWebsites = response
            saveLocalWebsites() // Cache for offline
            notifyWebsitesChanged()
        } catch {
            syncError = error
            // Keep using local websites
        }
    }

    private func handleRealtimeChange(_ change: AnyAction, userId: UUID) async {
        switch change {
        case .insert(let action):
            if let website = try? action.decodeRecord(as: BlockedWebsite.self, decoder: JSONDecoder()) {
                if !blockedWebsites.contains(where: { $0.id == website.id }) {
                    blockedWebsites.insert(website, at: 0)
                    saveLocalWebsites()
                    notifyWebsitesChanged()
                }
            }
        case .delete(let action):
            let oldRecord = action.oldRecord
            if let idString = oldRecord["id"]?.stringValue,
               let id = UUID(uuidString: idString) {
                blockedWebsites.removeAll { $0.id == id }
                saveLocalWebsites()
                notifyWebsitesChanged()
            }
        case .update(let action):
            if let website = try? action.decodeRecord(as: BlockedWebsite.self, decoder: JSONDecoder()) {
                if let index = blockedWebsites.firstIndex(where: { $0.id == website.id }) {
                    blockedWebsites[index] = website
                    saveLocalWebsites()
                    notifyWebsitesChanged()
                }
            }
        default:
            break
        }
    }

    private func notifyWebsitesChanged() {
        onWebsitesChanged?(domains)

        // Update platform-specific blockers
        #if os(iOS)
        Task {
            await SafariContentBlockerManager.shared.updateBlockedDomains(domains)
        }
        #elseif os(macOS)
        // Update macOS Network Extension with synced domains
        Task { @MainActor in
            NetworkExtensionManager.shared.updateBlockedDomains(domains)
        }
        #endif
    }
}
