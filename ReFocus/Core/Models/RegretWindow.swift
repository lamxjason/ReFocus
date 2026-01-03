import Foundation

// MARK: - Window Type

/// Types of regret prevention windows
enum RegretWindowType: String, Codable, CaseIterable, Identifiable {
    case lateNight = "lateNight"
    case postSession = "postSession"
    case custom = "custom"

    var id: String { rawValue }

    var defaultName: String {
        switch self {
        case .lateNight: return "Late Night Protection"
        case .postSession: return "Post-Session Shield"
        case .custom: return "Custom Window"
        }
    }

    var defaultMessage: String {
        switch self {
        case .lateNight:
            return "You tend to regret late-night browsing. Stay protected until morning."
        case .postSession:
            return "You just finished focusing. Stay protected during the vulnerability window."
        case .custom:
            return "Protection is active during this scheduled window."
        }
    }

    var icon: String {
        switch self {
        case .lateNight: return "moon.stars.fill"
        case .postSession: return "shield.checkered"
        case .custom: return "clock.badge.checkmark"
        }
    }
}

// MARK: - TimeComponents Extensions for Regret Prevention

extension TimeComponents {
    /// Display string (e.g., "11:00 PM")
    var displayString: String {
        formatted  // Use the existing `formatted` property
    }

    /// Check if current time falls within this time range
    func isWithinRange(to endTime: TimeComponents, at currentTime: TimeComponents) -> Bool {
        let start = self.totalMinutes
        let end = endTime.totalMinutes
        let current = currentTime.totalMinutes

        if start <= end {
            // Normal range (e.g., 9:00 AM to 5:00 PM)
            return current >= start && current < end
        } else {
            // Overnight range (e.g., 11:00 PM to 6:00 AM)
            return current >= start || current < end
        }
    }

    // Default times for regret prevention
    static let lateNightStart = TimeComponents(hour: 23, minute: 0)  // 11:00 PM
    static let lateNightEnd = TimeComponents(hour: 6, minute: 0)     // 6:00 AM
    static let midnight = TimeComponents(hour: 0, minute: 0)
    static let noon = TimeComponents(hour: 12, minute: 0)
}

// MARK: - Regret Window

/// A time window during which automatic protection is enabled
struct RegretWindow: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var type: RegretWindowType
    var isEnabled: Bool = true

    // Time-based windows (for lateNight and custom)
    var startTime: TimeComponents?
    var endTime: TimeComponents?

    // Duration-based windows (for postSession)
    var durationMinutes: Int?

    var message: String

    /// Whether this window is currently active
    var isCurrentlyActive: Bool {
        switch type {
        case .lateNight, .custom:
            guard let start = startTime, let end = endTime else { return false }
            let now = TimeComponents.from(date: Date())
            return start.isWithinRange(to: end, at: now)

        case .postSession:
            // Post-session is managed by RegretPreventionManager based on session end time
            return false
        }
    }

    // MARK: - Factory Methods

    /// Create default Late Night window
    static func defaultLateNight() -> RegretWindow {
        RegretWindow(
            name: RegretWindowType.lateNight.defaultName,
            type: .lateNight,
            isEnabled: true,
            startTime: .lateNightStart,
            endTime: .lateNightEnd,
            message: RegretWindowType.lateNight.defaultMessage
        )
    }

    /// Create default Post-Session window
    static func defaultPostSession() -> RegretWindow {
        RegretWindow(
            name: RegretWindowType.postSession.defaultName,
            type: .postSession,
            isEnabled: true,
            durationMinutes: 30,
            message: RegretWindowType.postSession.defaultMessage
        )
    }

    /// Create custom window
    static func custom(
        name: String,
        startTime: TimeComponents,
        endTime: TimeComponents,
        message: String? = nil
    ) -> RegretWindow {
        RegretWindow(
            name: name,
            type: .custom,
            isEnabled: true,
            startTime: startTime,
            endTime: endTime,
            message: message ?? RegretWindowType.custom.defaultMessage
        )
    }
}

// MARK: - Regret Prevention Config

/// Configuration for Regret Prevention Mode
struct RegretPreventionConfig: Codable, Equatable {
    var isEnabled: Bool = false
    var windows: [RegretWindow] = Self.defaultWindows

    /// Default set of windows
    static var defaultWindows: [RegretWindow] {
        [
            .defaultLateNight(),
            .defaultPostSession()
        ]
    }

    /// Get all enabled windows
    var enabledWindows: [RegretWindow] {
        windows.filter { $0.isEnabled }
    }

    /// Get time-based enabled windows (excludes post-session)
    var enabledTimeWindows: [RegretWindow] {
        windows.filter { $0.isEnabled && $0.type != .postSession }
    }

    /// Get post-session window if enabled
    var postSessionWindow: RegretWindow? {
        windows.first { $0.type == .postSession && $0.isEnabled }
    }

    /// Check if any time-based window is currently active
    func activeTimeWindow() -> RegretWindow? {
        enabledTimeWindows.first { $0.isCurrentlyActive }
    }

    /// Mutating methods for window management
    mutating func updateWindow(_ window: RegretWindow) {
        if let index = windows.firstIndex(where: { $0.id == window.id }) {
            windows[index] = window
        }
    }

    mutating func addWindow(_ window: RegretWindow) {
        windows.append(window)
    }

    mutating func removeWindow(id: UUID) {
        windows.removeAll { $0.id == id }
    }
}
