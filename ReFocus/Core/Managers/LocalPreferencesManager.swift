import Foundation
import SwiftUI

/// Manages local-only preferences that don't sync across devices
/// These are personal preferences about how the app behaves on this device
@MainActor
final class LocalPreferencesManager: ObservableObject {
    static let shared = LocalPreferencesManager()

    // MARK: - Published Properties

    /// When enabled, disables gamification elements (reward popups, level celebrations, XP displays)
    /// This aligns with users who want a calm, tool-like experience without engagement loops
    @Published var isMinimalModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMinimalModeEnabled, forKey: Keys.minimalMode)
        }
    }

    /// When enabled, shows streak warnings and at-risk indicators
    /// When disabled (minimal mode default), streaks are tracked but not emphasized
    @Published var showStreakWarnings: Bool {
        didSet {
            UserDefaults.standard.set(showStreakWarnings, forKey: Keys.showStreakWarnings)
        }
    }

    /// When enabled, shows daily reminder notifications
    @Published var showDailyReminders: Bool {
        didSet {
            UserDefaults.standard.set(showDailyReminders, forKey: Keys.showDailyReminders)
        }
    }

    // MARK: - Computed Properties

    /// Should show reward popups (disabled in minimal mode)
    var shouldShowRewardPopups: Bool {
        !isMinimalModeEnabled
    }

    /// Should show achievement celebrations (disabled in minimal mode)
    var shouldShowAchievementPopups: Bool {
        !isMinimalModeEnabled
    }

    /// Should show level up celebrations (disabled in minimal mode)
    var shouldShowLevelUpCelebrations: Bool {
        !isMinimalModeEnabled
    }

    /// Should display XP/level in the UI (hidden in minimal mode)
    var shouldShowXPDisplay: Bool {
        !isMinimalModeEnabled
    }

    // MARK: - Private

    private enum Keys {
        static let minimalMode = "localPrefs.minimalMode"
        static let showStreakWarnings = "localPrefs.showStreakWarnings"
        static let showDailyReminders = "localPrefs.showDailyReminders"
    }

    // MARK: - Initialization

    private init() {
        // Load saved preferences with sensible defaults
        // Default to minimal mode ON for new users (calm by default)
        // This aligns with the North Star: "Using the app should feel like reclaiming control"
        if UserDefaults.standard.object(forKey: Keys.minimalMode) == nil {
            // New user - default to minimal mode for calm experience
            self.isMinimalModeEnabled = true
        } else {
            // Existing user - respect their saved preference
            self.isMinimalModeEnabled = UserDefaults.standard.bool(forKey: Keys.minimalMode)
        }

        // Default to NOT showing streak warnings (aligns with minimal mode default)
        if UserDefaults.standard.object(forKey: Keys.showStreakWarnings) == nil {
            self.showStreakWarnings = false
        } else {
            self.showStreakWarnings = UserDefaults.standard.bool(forKey: Keys.showStreakWarnings)
        }

        // Default to showing daily reminders (helpful, not gamified)
        if UserDefaults.standard.object(forKey: Keys.showDailyReminders) == nil {
            self.showDailyReminders = true
        } else {
            self.showDailyReminders = UserDefaults.standard.bool(forKey: Keys.showDailyReminders)
        }
    }

    // MARK: - Methods

    /// Enable minimal mode - provides a calm, tool-like experience
    func enableMinimalMode() {
        isMinimalModeEnabled = true
        showStreakWarnings = false
    }

    /// Disable minimal mode - restores gamification features
    func disableMinimalMode() {
        isMinimalModeEnabled = false
        showStreakWarnings = true
    }
}
