import Foundation
import Supabase

/// Central Supabase client and authentication manager
@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    // MARK: - Configuration

    private static let supabaseURL = "https://hmqdcnxsbtfivyrdiolm.supabase.co"
    private static let supabaseAnonKey = "sb_publishable_UVq62Le756s_IN4P9bm_mg_2XhK_Wo3"

    // MARK: - Published State

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var currentUserId: UUID?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var authError: String?

    // MARK: - Supabase Client

    let client: SupabaseClient

    /// Whether the Supabase client was successfully configured
    @Published private(set) var isConfigured: Bool = true

    // MARK: - Initialization

    private init() {
        // Safely construct URL - use a fallback if invalid (shouldn't happen with hardcoded URL)
        let url = URL(string: Self.supabaseURL) ?? URL(string: "https://placeholder.supabase.co")!

        // Validate configuration
        if URL(string: Self.supabaseURL) == nil || Self.supabaseAnonKey.isEmpty {
            isConfigured = false
            authError = "Supabase is not configured correctly. The app will work offline only."
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Self.supabaseAnonKey
        )

        // Check for existing session on launch (only if configured)
        if isConfigured {
            Task {
                await checkExistingSession()
            }
        }
    }

    // MARK: - Auth Methods

    /// Sign in anonymously (for testing or guest mode)
    func signInAnonymously() async throws {
        isLoading = true
        authError = nil

        do {
            let response = try await client.auth.signInAnonymously()
            currentUserId = response.user.id
            isAuthenticated = true
            isLoading = false
        } catch {
            authError = error.localizedDescription
            isLoading = false
            throw error
        }
    }

    /// Sign in with Apple
    func signInWithApple(idToken: String, nonce: String) async throws {
        isLoading = true
        authError = nil

        do {
            let response = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            currentUserId = response.user.id
            isAuthenticated = true
            isLoading = false
        } catch {
            authError = error.localizedDescription
            isLoading = false
            throw error
        }
    }

    /// Sign out
    func signOut() async throws {
        isLoading = true

        do {
            try await client.auth.signOut()
            currentUserId = nil
            isAuthenticated = false
            isLoading = false
        } catch {
            isLoading = false
            throw error
        }
    }

    // MARK: - Session Management

    /// Check for existing session on app launch
    private func checkExistingSession() async {
        isLoading = true

        do {
            let session = try await client.auth.session
            currentUserId = session.user.id
            isAuthenticated = true
        } catch {
            // No existing session, user needs to sign in
            isAuthenticated = false
            currentUserId = nil
        }

        isLoading = false
    }

    /// Refresh the current session if needed
    func refreshSession() async throws {
        let session = try await client.auth.session
        currentUserId = session.user.id
        isAuthenticated = true
    }

    // MARK: - Database Helpers

    /// Get the current user ID, throwing if not authenticated
    func requireUserId() throws -> UUID {
        guard let userId = currentUserId else {
            throw SupabaseError.notAuthenticated
        }
        return userId
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case notAuthenticated
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .invalidConfiguration:
            return "Supabase is not configured correctly."
        }
    }
}
