import SwiftUI

@main
struct ReFocusApp: App {
    // MARK: - Managers

    @StateObject private var supabaseManager = SupabaseManager.shared
    @StateObject private var timerSyncManager = TimerSyncManager.shared
    @StateObject private var websiteSyncManager = WebsiteSyncManager.shared
    @StateObject private var blockEnforcementManager = BlockEnforcementManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabaseManager)
                .environmentObject(timerSyncManager)
                .environmentObject(websiteSyncManager)
                .environmentObject(blockEnforcementManager)
                .task {
                    await setupSync()
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(supabaseManager)
                .environmentObject(timerSyncManager)
                .environmentObject(websiteSyncManager)
                .environmentObject(blockEnforcementManager)
        }
        #endif
    }

    // MARK: - Setup

    private func setupSync() async {
        // Try to sign in, but don't block the app if it fails
        // The app works fully offline with local timer and storage
        if !supabaseManager.isAuthenticated {
            do {
                try await supabaseManager.signInAnonymously()
            } catch {
                // Sign-in failed - app will work offline
                print("Auth error (app will work offline): \(error)")
                return
            }
        }

        // Subscribe to realtime updates if authenticated
        if supabaseManager.isAuthenticated {
            do {
                try await timerSyncManager.subscribe()
                try await websiteSyncManager.subscribe()
            } catch {
                print("Sync setup error (app will work offline): \(error)")
            }
        }
    }
}
