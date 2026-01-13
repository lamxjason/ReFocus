import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

/// DeviceActivityMonitor that enforces schedule-based blocking
/// Runs as a separate process and receives callbacks when schedule intervals start/end
class ScheduleMonitor: DeviceActivityMonitor {

    // MARK: - App Group Shared Data

    private let appGroupId = "group.com.refocus.shared"
    private let schedulesKey = "deviceActivitySchedules"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    // Use the schedule store (same name as main app)
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("schedule"))

    // MARK: - DeviceActivityMonitor Callbacks

    /// Called when a scheduled interval begins
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard let scheduleData = loadScheduleData(for: activity.rawValue) else {
            return
        }

        applyBlocks(from: scheduleData)
        logEvent("Schedule started: \(activity.rawValue)")
    }

    /// Called when a scheduled interval ends
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        removeAllBlocks()
        logEvent("Schedule ended: \(activity.rawValue)")
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    // MARK: - Blocking Logic

    private func applyBlocks(from data: SharedScheduleData) {
        if let appTokensData = data.appTokensData,
           let tokens = try? JSONDecoder().decode(Set<ApplicationToken>.self, from: appTokensData) {
            store.shield.applications = tokens
        }

        if let categoryTokensData = data.categoryTokensData,
           let tokens = try? JSONDecoder().decode(Set<ActivityCategoryToken>.self, from: categoryTokensData) {
            store.shield.applicationCategories = .specific(tokens)
        }

        if let webTokensData = data.webDomainTokensData,
           let tokens = try? JSONDecoder().decode(Set<WebDomainToken>.self, from: webTokensData) {
            store.shield.webDomains = tokens
        }
    }

    private func removeAllBlocks() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    private func loadScheduleData(for activityName: String) -> SharedScheduleData? {
        guard let defaults = sharedDefaults,
              let allSchedulesData = defaults.data(forKey: schedulesKey),
              let allSchedules = try? JSONDecoder().decode([String: SharedScheduleData].self, from: allSchedulesData) else {
            return nil
        }
        return allSchedules[activityName]
    }

    private func logEvent(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)"

        if let defaults = sharedDefaults {
            var logs = defaults.stringArray(forKey: "scheduleMonitorLogs") ?? []
            logs.append(logEntry)
            if logs.count > 100 {
                logs = Array(logs.suffix(100))
            }
            defaults.set(logs, forKey: "scheduleMonitorLogs")
        }
    }
}

// MARK: - Shared Data Model

struct SharedScheduleData: Codable {
    let scheduleId: String
    let scheduleName: String
    let isStrictMode: Bool
    var appTokensData: Data?
    var categoryTokensData: Data?
    var webDomainTokensData: Data?

    init(scheduleId: String, scheduleName: String, isStrictMode: Bool) {
        self.scheduleId = scheduleId
        self.scheduleName = scheduleName
        self.isStrictMode = isStrictMode
    }
}
