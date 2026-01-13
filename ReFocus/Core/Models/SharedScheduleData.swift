import Foundation

/// Data structure shared between main app and DeviceActivityMonitor extension
/// Used for passing schedule blocking configuration via App Group UserDefaults
struct SharedScheduleData: Codable {
    let scheduleId: String
    let scheduleName: String
    let isStrictMode: Bool

    // Encoded FamilyActivitySelection tokens as Data
    // We encode as Data because tokens are opaque and device-specific
    var appTokensData: Data?
    var categoryTokensData: Data?
    var webDomainTokensData: Data?

    init(scheduleId: String, scheduleName: String, isStrictMode: Bool) {
        self.scheduleId = scheduleId
        self.scheduleName = scheduleName
        self.isStrictMode = isStrictMode
    }
}
