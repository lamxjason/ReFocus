import Foundation

/// Represents the shared timer state synced across all devices via Supabase
/// This is the single source of truth for whether a focus session is active
struct SharedTimerState: Codable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    var isActive: Bool
    var startTime: Date?
    var endTime: Date?
    var plannedDurationSeconds: Int?
    var lastModifiedBy: String
    var lastModifiedAt: Date

    // MARK: - Computed Properties

    var remainingTime: TimeInterval? {
        guard isActive, let endTime = endTime else { return nil }
        return max(0, endTime.timeIntervalSinceNow)
    }

    var hasExpired: Bool {
        guard isActive, let endTime = endTime else { return false }
        return Date() >= endTime
    }

    var totalDuration: TimeInterval? {
        guard let seconds = plannedDurationSeconds else { return nil }
        return TimeInterval(seconds)
    }

    var progress: Double {
        guard let total = totalDuration, total > 0, let remaining = remainingTime else { return 0 }
        return 1.0 - (remaining / total)
    }

    var formattedRemainingTime: String {
        guard let remaining = remainingTime else { return "00:00" }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Supabase Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case isActive = "is_active"
        case startTime = "start_time"
        case endTime = "end_time"
        case plannedDurationSeconds = "planned_duration_seconds"
        case lastModifiedBy = "last_modified_by"
        case lastModifiedAt = "last_modified_at"
    }

    // MARK: - Factory Methods

    static func inactive(userId: UUID, deviceId: String) -> SharedTimerState {
        SharedTimerState(
            id: UUID(),
            userId: userId,
            isActive: false,
            startTime: nil,
            endTime: nil,
            plannedDurationSeconds: nil,
            lastModifiedBy: deviceId,
            lastModifiedAt: Date()
        )
    }

    // MARK: - Mutations

    mutating func activate(duration: TimeInterval, deviceId: String) {
        let now = Date()
        isActive = true
        startTime = now
        endTime = now.addingTimeInterval(duration)
        plannedDurationSeconds = Int(duration)
        lastModifiedBy = deviceId
        lastModifiedAt = Date()
    }

    mutating func deactivate(deviceId: String) {
        isActive = false
        lastModifiedBy = deviceId
        lastModifiedAt = Date()
    }

    mutating func extend(by seconds: TimeInterval, deviceId: String) {
        guard isActive, let currentEnd = endTime else { return }
        endTime = currentEnd.addingTimeInterval(seconds)
        if let current = plannedDurationSeconds {
            plannedDurationSeconds = current + Int(seconds)
        }
        lastModifiedBy = deviceId
        lastModifiedAt = Date()
    }
}
