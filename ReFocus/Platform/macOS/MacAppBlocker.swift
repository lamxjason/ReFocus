import Foundation

#if os(macOS)
import AppKit
import UserNotifications

/// Manages app blocking on macOS using NSWorkspace observation
/// This is device-local blocking, not synced between devices
@MainActor
final class MacAppBlocker: ObservableObject {
    static let shared = MacAppBlocker()

    // MARK: - Published State

    @Published var isEnabled: Bool = false
    @Published var blockedBundleIds: Set<String> = []
    @Published private(set) var blockedApps: [BlockedMacApp] = []

    // MARK: - Private

    private var workspaceObserver: Any?

    private init() {
        loadSavedState()
    }

    // MARK: - Blocking Control

    func startBlocking() {
        guard !blockedBundleIds.isEmpty else { return }

        isEnabled = true

        // Start observing app launches
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract data on main thread before passing to @MainActor method
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier else {
                return
            }
            let appName = app.localizedName ?? bundleId
            Task { @MainActor [weak self] in
                self?.handleAppLaunch(bundleId: bundleId, app: app, appName: appName)
            }
        }

        // Terminate any currently running blocked apps
        terminateBlockedApps()
    }

    func stopBlocking() {
        isEnabled = false

        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
    }

    // MARK: - App Selection

    func addBlockedApp(_ app: BlockedMacApp) {
        guard !blockedBundleIds.contains(app.bundleId) else { return }
        blockedApps.append(app)
        blockedBundleIds.insert(app.bundleId)
        saveState()
    }

    func removeBlockedApp(_ app: BlockedMacApp) {
        blockedApps.removeAll { $0.bundleId == app.bundleId }
        blockedBundleIds.remove(app.bundleId)
        saveState()
    }

    func removeBlockedApp(bundleId: String) {
        blockedApps.removeAll { $0.bundleId == bundleId }
        blockedBundleIds.remove(bundleId)
        saveState()
    }

    // MARK: - Private Methods

    private func handleAppLaunch(bundleId: String, app: NSRunningApplication, appName: String) {
        guard blockedBundleIds.contains(bundleId) else {
            return
        }

        // Terminate the blocked app
        app.terminate()

        // Show notification to user
        showBlockedNotification(appName: appName)
    }

    private func terminateBlockedApps() {
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier,
                  blockedBundleIds.contains(bundleId) else {
                continue
            }

            app.terminate()
        }
    }

    private func showBlockedNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "App Blocked"
        content.body = "\(appName) is blocked during your focus session."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show blocked notification: \(error)")
            }
        }
    }

    // MARK: - Persistence

    private static let storageKey = "macBlockedApps"

    private func saveState() {
        guard let data = try? JSONEncoder().encode(blockedApps) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func loadSavedState() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let apps = try? JSONDecoder().decode([BlockedMacApp].self, from: data) else {
            return
        }

        blockedApps = apps
        blockedBundleIds = Set(apps.map { $0.bundleId })
    }
}

// MARK: - BlockedMacApp Model

struct BlockedMacApp: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let bundleId: String
    let name: String
    let iconData: Data?

    init(bundleId: String, name: String, iconData: Data? = nil) {
        self.id = UUID()
        self.bundleId = bundleId
        self.name = name
        self.iconData = iconData
    }

    static func fromRunningApplication(_ app: NSRunningApplication) -> BlockedMacApp? {
        guard let bundleId = app.bundleIdentifier else { return nil }

        var iconData: Data?
        if let icon = app.icon,
           let tiffData = icon.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData) {
            iconData = bitmap.representation(using: .png, properties: [:])
        }

        return BlockedMacApp(
            bundleId: bundleId,
            name: app.localizedName ?? bundleId,
            iconData: iconData
        )
    }
}
#endif
