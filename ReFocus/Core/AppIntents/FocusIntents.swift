import AppIntents
import Foundation

// MARK: - Start Focus Session Intent

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus Session"
    static let description = IntentDescription("Start a focus session to block distracting apps")
    
    @Parameter(title: "Duration (minutes)", default: 25)
    var duration: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$duration) minute focus session")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Validate duration
        let validDuration = max(5, min(duration, 180))
        
        // Start the session via TimerSyncManager
        await MainActor.run {
            let timerSync = TimerSyncManager.shared
            Task {
                try? await timerSync.startTimer(durationMinutes: validDuration)
            }
        }
        
        return .result(dialog: "Starting a \(validDuration) minute focus session. Stay focused!")
    }
    
    static let openAppWhenRun: Bool = false
}

// MARK: - Stop Focus Session Intent

struct StopFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Focus Session"
    static let description = IntentDescription("Stop the current focus session")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            let timerSync = TimerSyncManager.shared
            Task {
                try? await timerSync.stopTimer()
            }
        }
        
        return .result(dialog: "Focus session ended.")
    }
}

// MARK: - Check Streak Intent

struct CheckStreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Focus Streak"
    static let description = IntentDescription("Check your current focus streak")
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let stats = await MainActor.run { StatsManager.shared }
        let streak = await MainActor.run { stats.currentStreak }
        let level = await MainActor.run { stats.level }
        
        if streak > 0 {
            return .result(dialog: "You have a \(streak) day streak! You're level \(level). Keep it up!")
        } else {
            return .result(dialog: "You don't have an active streak yet. Start a focus session to begin!")
        }
    }
}

// MARK: - Quick Focus Intent (15, 25, 45 min presets)

struct QuickFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Focus"
    static let description = IntentDescription("Start a quick focus session with preset duration")
    
    @Parameter(title: "Duration")
    var preset: FocusDurationPreset
    
    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$preset) focus session")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            let timerSync = TimerSyncManager.shared
            Task {
                try? await timerSync.startTimer(durationMinutes: preset.minutes)
            }
        }
        
        return .result(dialog: "Starting a \(preset.minutes) minute focus session!")
    }
}

enum FocusDurationPreset: String, AppEnum {
    case short = "short"
    case pomodoro = "pomodoro"
    case medium = "medium"
    case long = "long"
    
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Focus Duration"
    
    static let caseDisplayRepresentations: [FocusDurationPreset: DisplayRepresentation] = [
        .short: "15 minutes",
        .pomodoro: "25 minutes (Pomodoro)",
        .medium: "45 minutes",
        .long: "60 minutes"
    ]
    
    var minutes: Int {
        switch self {
        case .short: return 15
        case .pomodoro: return 25
        case .medium: return 45
        case .long: return 60
        }
    }
}

// MARK: - App Shortcuts Provider

struct ReFocusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "Start focus in \(.applicationName)",
                "Start a focus session with \(.applicationName)",
                "Focus with \(.applicationName)",
                "Help me focus with \(.applicationName)"
            ],
            shortTitle: "Start Focus",
            systemImageName: "brain.head.profile"
        )
        
        AppShortcut(
            intent: QuickFocusIntent(),
            phrases: [
                "Quick focus with \(.applicationName)",
                "Start quick focus in \(.applicationName)"
            ],
            shortTitle: "Quick Focus",
            systemImageName: "play.circle"
        )
        
        AppShortcut(
            intent: StopFocusIntent(),
            phrases: [
                "Stop focus in \(.applicationName)",
                "End focus session with \(.applicationName)",
                "Stop focusing with \(.applicationName)"
            ],
            shortTitle: "Stop Focus",
            systemImageName: "stop.circle"
        )
        
        AppShortcut(
            intent: CheckStreakIntent(),
            phrases: [
                "Check my streak in \(.applicationName)",
                "What's my focus streak in \(.applicationName)",
                "How long is my streak in \(.applicationName)"
            ],
            shortTitle: "Check Streak",
            systemImageName: "flame"
        )
    }
}
