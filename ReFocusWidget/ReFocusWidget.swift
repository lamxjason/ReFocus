import WidgetKit
import SwiftUI

/// Main widget bundle containing all ReFocus widgets
@main
struct ReFocusWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        FocusStatusWidget()
        QuickStartWidget()
    }
}

// MARK: - Shared Data Provider

/// Shared data structure for widgets
struct WidgetData {
    let currentStreak: Int
    let level: Int
    let totalFocusMinutes: Int
    let isSessionActive: Bool
    let sessionEndTime: Date?
    let todayFocusMinutes: Int
    
    static let placeholder = WidgetData(
        currentStreak: 7,
        level: 5,
        totalFocusMinutes: 1200,
        isSessionActive: false,
        sessionEndTime: nil,
        todayFocusMinutes: 45
    )
    
    static func load() -> WidgetData {
        let defaults = UserDefaults(suiteName: "group.com.refocus.shared")
        
        return WidgetData(
            currentStreak: defaults?.integer(forKey: "widget_currentStreak") ?? 0,
            level: defaults?.integer(forKey: "widget_level") ?? 1,
            totalFocusMinutes: defaults?.integer(forKey: "widget_totalFocusMinutes") ?? 0,
            isSessionActive: defaults?.bool(forKey: "widget_isSessionActive") ?? false,
            sessionEndTime: defaults?.object(forKey: "widget_sessionEndTime") as? Date,
            todayFocusMinutes: defaults?.integer(forKey: "widget_todayFocusMinutes") ?? 0
        )
    }
}

// MARK: - Widget Colors

extension Color {
    static let widgetAccent = Color(red: 0.4, green: 0.6, blue: 1.0)
    static let widgetBackground = Color(red: 0.1, green: 0.1, blue: 0.15)
    static let widgetStreak = Color.orange
}
