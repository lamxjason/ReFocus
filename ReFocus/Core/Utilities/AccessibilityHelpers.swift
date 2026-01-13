import SwiftUI

// MARK: - Accessibility View Modifiers

extension View {
    /// Add accessibility label and hint for interactive elements
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility for timer display
    func accessibleTimer(minutes: Int, seconds: Int, isActive: Bool) -> some View {
        self
            .accessibilityLabel(isActive
                ? "Timer: \(minutes) minutes, \(seconds) seconds remaining"
                : "Timer: \(minutes) minutes, \(seconds) seconds")
            .accessibilityValue(isActive ? "Running" : "Stopped")
    }

    /// Add accessibility for progress indicators
    func accessibleProgress(value: Double, label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue("\(Int(value * 100)) percent")
    }

    /// Add accessibility for stat displays
    func accessibleStat(label: String, value: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label): \(value)")
    }

    /// Add accessibility for toggle controls
    func accessibleToggle(label: String, isOn: Bool, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityHint(hint ?? "Double tap to toggle")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility for navigation elements
    func accessibleNavigation(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "Double tap to navigate")
            .accessibilityAddTraits(.isButton)
    }

    /// Group elements for accessibility
    func accessibilityGrouped(label: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
    }
}

// MARK: - Accessibility Labels

/// Standard accessibility labels for consistent VoiceOver experience
enum AccessibilityLabels {
    // Timer
    static let startFocus = "Start focus session"
    static let stopFocus = "Stop focus session"
    static let pauseFocus = "Pause focus session"
    static let resumeFocus = "Resume focus session"
    static let extendTimer = "Extend timer"

    // Duration
    static func duration(_ minutes: Int) -> String {
        "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }

    // Modes
    static let selectMode = "Select focus mode"
    static let timerMode = "Timer mode"
    static let scheduleMode = "Schedule mode"

    // Settings
    static let strictMode = "Strict mode"
    static let strictModeHint = "When enabled, apps cannot be unblocked during focus sessions"

    // Stats
    static func streak(_ days: Int) -> String {
        "\(days) day\(days == 1 ? "" : "s") streak"
    }

    static func xp(_ points: Int) -> String {
        "\(points) experience points"
    }

    static func level(_ level: Int) -> String {
        "Level \(level)"
    }

    // Schedule
    static let viewSchedules = "View schedules"
    static let createSchedule = "Create new schedule"
    static let editSchedule = "Edit schedule"
    static let deleteSchedule = "Delete schedule"

    // Websites
    static let addWebsite = "Add website to block list"
    static let removeWebsite = "Remove website from block list"

    // Apps
    static let selectApps = "Select apps to block"

    // Social
    static let viewFriends = "View friends"
    static let viewChallenges = "View challenges"
    static let viewLeaderboard = "View leaderboard"
}
