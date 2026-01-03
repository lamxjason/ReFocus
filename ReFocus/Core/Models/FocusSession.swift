import Foundation

/// Represents a completed or in-progress focus session
struct FocusSession: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let deviceId: String
    let startTime: Date
    var endTime: Date?
    let plannedDurationSeconds: Int
    var actualDurationSeconds: Int?
    var wasCompleted: Bool
    let blockedWebsiteCount: Int
    let blockedAppCount: Int
    let blockedWebsites: [String]  // Actual domains that were blocked
    let modeName: String?          // Focus mode used for this session
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceId = "device_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case plannedDurationSeconds = "planned_duration_seconds"
        case actualDurationSeconds = "actual_duration_seconds"
        case wasCompleted = "was_completed"
        case blockedWebsiteCount = "blocked_website_count"
        case blockedAppCount = "blocked_app_count"
        case blockedWebsites = "blocked_websites"
        case modeName = "mode_name"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        deviceId: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        plannedDurationSeconds: Int,
        actualDurationSeconds: Int? = nil,
        wasCompleted: Bool = false,
        blockedWebsiteCount: Int = 0,
        blockedAppCount: Int = 0,
        blockedWebsites: [String] = [],
        modeName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.deviceId = deviceId
        self.startTime = startTime
        self.endTime = endTime
        self.plannedDurationSeconds = plannedDurationSeconds
        self.actualDurationSeconds = actualDurationSeconds
        self.wasCompleted = wasCompleted
        self.blockedWebsiteCount = blockedWebsiteCount
        self.blockedAppCount = blockedAppCount
        self.blockedWebsites = blockedWebsites
        self.modeName = modeName
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    var isCompleted: Bool {
        endTime != nil
    }

    var duration: TimeInterval {
        if let actual = actualDurationSeconds {
            return TimeInterval(actual)
        }
        return TimeInterval(plannedDurationSeconds)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(minutes) min"
    }

    var successRate: Double {
        guard let actual = actualDurationSeconds, plannedDurationSeconds > 0 else { return 0 }
        return min(1.0, Double(actual) / Double(plannedDurationSeconds))
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }

    // MARK: - Mutations

    mutating func complete() {
        let now = Date()
        endTime = now
        actualDurationSeconds = Int(now.timeIntervalSince(startTime))
        wasCompleted = true
    }

    mutating func cancel() {
        let now = Date()
        endTime = now
        actualDurationSeconds = Int(now.timeIntervalSince(startTime))
        wasCompleted = false
    }
}
