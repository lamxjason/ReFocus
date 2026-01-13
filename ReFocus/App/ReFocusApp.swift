import SwiftUI

@main
struct ReFocusApp: App {
    // MARK: - Managers

    @StateObject private var supabaseManager = SupabaseManager.shared
    @StateObject private var syncCoordinator = SyncCoordinator.shared
    @StateObject private var timerSyncManager = TimerSyncManager.shared
    @StateObject private var websiteSyncManager = WebsiteSyncManager.shared
    @StateObject private var blockEnforcementManager = BlockEnforcementManager.shared
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabaseManager)
                .environmentObject(syncCoordinator)
                .environmentObject(timerSyncManager)
                .environmentObject(websiteSyncManager)
                .environmentObject(blockEnforcementManager)
                .environmentObject(notificationManager)
                .task {
                    await setupSync()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
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
                .environmentObject(syncCoordinator)
                .environmentObject(timerSyncManager)
                .environmentObject(websiteSyncManager)
                .environmentObject(blockEnforcementManager)
        }
        #endif
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "refocus" else { return }

        switch url.host {
        case "start":
            // Handle start focus from widget: refocus://start?duration=25
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let durationString = components.queryItems?.first(where: { $0.name == "duration" })?.value,
               let duration = Int(durationString) {
                Task {
                    try? await timerSyncManager.startTimer(durationMinutes: duration)
                }
            }
        case "stop":
            Task {
                try? await timerSyncManager.stopTimer()
            }
        case "extend":
            // Handle extend from Live Activity: refocus://extend?minutes=5
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let minutesString = components.queryItems?.first(where: { $0.name == "minutes" })?.value,
               let minutes = Int(minutesString) {
                Task {
                    try? await timerSyncManager.extendTimer(by: TimeInterval(minutes * 60))
                }
            }
        case "family":
            // Could navigate to family view
            break
        default:
            break
        }
    }

    // MARK: - Setup

    private func setupSync() async {
        // Request notification authorization
        await setupNotifications()
        
        // Try to sign in, but don't block the app if it fails
        // The app works fully offline with local timer and storage
        if !supabaseManager.isAuthenticated {
            do {
                try await supabaseManager.signInAnonymously()
            } catch {
                // Sign-in failed - app will work offline
                Log.Auth.error("Auth error (app will work offline)", error: error)
                return
            }
        }

        // SyncCoordinator automatically subscribes all managers when authenticated
        // It listens to auth state changes from SupabaseManager
        // This ensures all sync managers (modes, schedules, settings, stats, timer, websites)
        // are subscribed to Realtime updates across all devices
    }
    
    private func setupNotifications() async {
        // Request notification authorization
        do {
            try await notificationManager.requestAuthorization()
        } catch {
            Log.error("Notification authorization failed", error: error)
        }
        
        // Schedule streak warning if streak is at risk
        let stats = StatsManager.shared
        if stats.isStreakAtRisk {
            notificationManager.scheduleStreakWarning(
                currentStreak: stats.currentStreak,
                hoursUntilLost: stats.hoursRemainingToProtectStreak
            )
        }
    }
}
