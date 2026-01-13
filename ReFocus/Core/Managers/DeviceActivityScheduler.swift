import Foundation
#if os(iOS)
import DeviceActivity
import FamilyControls

/// Registers schedules with DeviceActivityCenter for background enforcement
/// Works with the ReFocusDeviceMonitor extension
@MainActor
final class DeviceActivityScheduler: ObservableObject {
    static let shared = DeviceActivityScheduler()

    // MARK: - App Group

    private let appGroupId = "group.com.refocus.shared"
    private let schedulesKey = "deviceActivitySchedules"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    private let center = DeviceActivityCenter()

    // MARK: - Published State

    @Published private(set) var registeredSchedules: Set<String> = []
    @Published private(set) var lastError: Error?

    private init() {
        loadRegisteredSchedules()
    }

    // MARK: - Schedule Registration

    /// Register a FocusSchedule with DeviceActivityCenter
    func registerSchedule(_ schedule: FocusSchedule) throws {
        guard schedule.isEnabled else { return }

        let activityName = DeviceActivityName(schedule.id.uuidString)

        // Convert FocusSchedule to DeviceActivitySchedule
        let deviceSchedule = try createDeviceSchedule(from: schedule)

        // Save blocking data to shared defaults for the extension
        saveScheduleData(schedule)

        // Register with DeviceActivityCenter
        try center.startMonitoring(activityName, during: deviceSchedule)

        registeredSchedules.insert(schedule.id.uuidString)
        saveRegisteredSchedules()

        lastError = nil
    }

    /// Unregister a schedule from DeviceActivityCenter
    func unregisterSchedule(_ scheduleId: UUID) {
        let activityName = DeviceActivityName(scheduleId.uuidString)
        center.stopMonitoring([activityName])

        removeScheduleData(scheduleId.uuidString)
        registeredSchedules.remove(scheduleId.uuidString)
        saveRegisteredSchedules()
    }

    /// Update a schedule (unregister then re-register)
    func updateSchedule(_ schedule: FocusSchedule) throws {
        unregisterSchedule(schedule.id)
        if schedule.isEnabled {
            try registerSchedule(schedule)
        }
    }

    /// Register all enabled schedules
    func registerAllSchedules(_ schedules: [FocusSchedule]) {
        // First, unregister all current schedules
        for scheduleId in registeredSchedules {
            if let uuid = UUID(uuidString: scheduleId) {
                unregisterSchedule(uuid)
            }
        }

        // Register all enabled schedules
        for schedule in schedules where schedule.isEnabled {
            do {
                try registerSchedule(schedule)
            } catch {
                lastError = error
            }
        }
    }

    /// Unregister all schedules
    func unregisterAllSchedules() {
        for scheduleId in registeredSchedules {
            if let uuid = UUID(uuidString: scheduleId) {
                unregisterSchedule(uuid)
            }
        }
    }

    // MARK: - DeviceActivitySchedule Creation

    private func createDeviceSchedule(from schedule: FocusSchedule) throws -> DeviceActivitySchedule {
        // Create DateComponents for start and end times
        var startComponents = DateComponents()
        startComponents.hour = schedule.startTime.hour
        startComponents.minute = schedule.startTime.minute

        var endComponents = DateComponents()
        endComponents.hour = schedule.endTime.hour
        endComponents.minute = schedule.endTime.minute

        // Create the schedule
        // DeviceActivitySchedule repeats automatically based on intervalStart/intervalEnd
        let deviceSchedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: true,
            warningTime: DateComponents(minute: 5) // 5 min warning before start
        )

        return deviceSchedule
    }

    // MARK: - Shared Data Management

    private func saveScheduleData(_ schedule: FocusSchedule) {
        guard let defaults = sharedDefaults else { return }

        var sharedData = SharedScheduleData(
            scheduleId: schedule.id.uuidString,
            scheduleName: schedule.name,
            isStrictMode: schedule.isStrictMode
        )

        // Encode the FamilyActivitySelection tokens
        if let selection = schedule.appSelection {
            sharedData.appTokensData = try? JSONEncoder().encode(selection.applicationTokens)
            sharedData.categoryTokensData = try? JSONEncoder().encode(selection.categoryTokens)
            sharedData.webDomainTokensData = try? JSONEncoder().encode(selection.webDomainTokens)
        }

        // Load existing schedules, add/update this one
        var allSchedules = loadAllScheduleData()
        allSchedules[schedule.id.uuidString] = sharedData

        // Save back
        if let data = try? JSONEncoder().encode(allSchedules) {
            defaults.set(data, forKey: schedulesKey)
        }
    }

    private func removeScheduleData(_ scheduleId: String) {
        guard let defaults = sharedDefaults else { return }

        var allSchedules = loadAllScheduleData()
        allSchedules.removeValue(forKey: scheduleId)

        if let data = try? JSONEncoder().encode(allSchedules) {
            defaults.set(data, forKey: schedulesKey)
        }
    }

    private func loadAllScheduleData() -> [String: SharedScheduleData] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: schedulesKey),
              let schedules = try? JSONDecoder().decode([String: SharedScheduleData].self, from: data) else {
            return [:]
        }
        return schedules
    }

    // MARK: - Persistence

    private func loadRegisteredSchedules() {
        if let saved = UserDefaults.standard.stringArray(forKey: "registeredDeviceActivitySchedules") {
            registeredSchedules = Set(saved)
        }
    }

    private func saveRegisteredSchedules() {
        UserDefaults.standard.set(Array(registeredSchedules), forKey: "registeredDeviceActivitySchedules")
    }

    // MARK: - Debug

    /// Get logs from the monitor extension
    func getMonitorLogs() -> [String] {
        sharedDefaults?.stringArray(forKey: "scheduleMonitorLogs") ?? []
    }

    /// Clear monitor logs
    func clearMonitorLogs() {
        sharedDefaults?.removeObject(forKey: "scheduleMonitorLogs")
    }
}
#endif
