import Foundation
import WidgetKit

/// Manages data sharing between the main app and widgets via App Group
@MainActor
final class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private let appGroupId = "group.com.refocus.shared"
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }
    
    private init() {}
    
    // MARK: - Update Widget Data
    
    /// Update all widget data from current app state
    func updateWidgetData() {
        let stats = StatsManager.shared
        let timerSync = TimerSyncManager.shared
        
        // Calculate minutes from available properties
        let todayMinutes = stats.todaySessions.reduce(0) { $0 + ($1.actualDurationSeconds ?? 0) } / 60
        let totalMinutes = Int(stats.totalFocusTime / 60)
        
        defaults?.set(stats.currentStreak, forKey: "widget_currentStreak")
        defaults?.set(stats.level, forKey: "widget_level")
        defaults?.set(totalMinutes, forKey: "widget_totalFocusMinutes")
        defaults?.set(todayMinutes, forKey: "widget_todayFocusMinutes")
        
        // Session state
        if let timerState = timerSync.timerState, timerState.isActive {
            defaults?.set(true, forKey: "widget_isSessionActive")
            defaults?.set(timerState.endTime, forKey: "widget_sessionEndTime")
        } else {
            defaults?.set(false, forKey: "widget_isSessionActive")
            defaults?.removeObject(forKey: "widget_sessionEndTime")
        }
        
        // Request widget refresh
        reloadWidgets()
    }
    
    /// Update session state for active focus session
    func updateSessionState(isActive: Bool, endTime: Date?) {
        defaults?.set(isActive, forKey: "widget_isSessionActive")
        if let endTime = endTime {
            defaults?.set(endTime, forKey: "widget_sessionEndTime")
        } else {
            defaults?.removeObject(forKey: "widget_sessionEndTime")
        }
        
        reloadWidgets()
    }
    
    /// Update streak and level after session completion
    func updateStats(streak: Int, level: Int, todayMinutes: Int, totalMinutes: Int) {
        defaults?.set(streak, forKey: "widget_currentStreak")
        defaults?.set(level, forKey: "widget_level")
        defaults?.set(todayMinutes, forKey: "widget_todayFocusMinutes")
        defaults?.set(totalMinutes, forKey: "widget_totalFocusMinutes")
        
        reloadWidgets()
    }
    
    // MARK: - Widget Refresh
    
    /// Request all widgets to reload their timelines
    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Reload specific widget kind
    func reloadWidget(kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
