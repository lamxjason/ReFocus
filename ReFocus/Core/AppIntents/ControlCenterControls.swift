#if os(iOS)
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Start Focus Control (iOS 18+)

/// Control Center button to start a quick focus session
@available(iOS 18.0, *)
struct StartFocusControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.refocus.start-focus",
            provider: StartFocusValueProvider()
        ) { value in
            ControlWidgetButton(action: StartQuickFocusControlIntent()) {
                Label(value ? "Focusing" : "Focus", systemImage: "brain.head.profile")
            }
        }
        .displayName("Start Focus")
        .description("Start a quick 25-minute focus session")
    }
}

@available(iOS 18.0, *)
struct StartFocusValueProvider: ControlValueProvider {
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool {
        await MainActor.run {
            TimerSyncManager.shared.timerState?.isActive ?? false
        }
    }
}

@available(iOS 18.0, *)
struct StartQuickFocusControlIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Start Quick Focus"
    static let isDiscoverable = true

    func perform() async throws -> some IntentResult {
        let isActive = await MainActor.run {
            TimerSyncManager.shared.timerState?.isActive ?? false
        }

        if isActive {
            // Stop the current session
            await MainActor.run {
                Task {
                    try? await TimerSyncManager.shared.stopTimer()
                }
            }
        } else {
            // Start a 25-minute session
            await MainActor.run {
                Task {
                    try? await TimerSyncManager.shared.startTimer(durationMinutes: 25)
                }
            }
        }

        return .result()
    }
}

// MARK: - Focus Timer Control (iOS 18+)

/// Control Center toggle showing focus status with timer
@available(iOS 18.0, *)
struct FocusTimerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.refocus.focus-timer",
            provider: FocusTimerValueProvider()
        ) { value in
            ControlWidgetToggle(isOn: value.isActive, action: ToggleFocusControlIntent()) {
                if value.isActive {
                    Label {
                        Text(value.remainingText)
                    } icon: {
                        Image(systemName: "brain.head.profile")
                    }
                } else {
                    Label("Focus", systemImage: "brain.head.profile")
                }
            }
        }
        .displayName("Focus Timer")
        .description("Toggle focus session with timer display")
    }
}

struct FocusTimerState {
    let isActive: Bool
    let remainingText: String

    static let inactive = FocusTimerState(isActive: false, remainingText: "Off")
}

@available(iOS 18.0, *)
struct FocusTimerValueProvider: ControlValueProvider {
    var previewValue: FocusTimerState { .inactive }

    func currentValue() async throws -> FocusTimerState {
        await MainActor.run {
            guard let state = TimerSyncManager.shared.timerState,
                  state.isActive,
                  let remaining = state.remainingTime else {
                return .inactive
            }

            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            let text = String(format: "%d:%02d", minutes, seconds)

            return FocusTimerState(isActive: true, remainingText: text)
        }
    }
}

@available(iOS 18.0, *)
struct ToggleFocusControlIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Focus"

    @Parameter(title: "Focus Active")
    var value: Bool

    func perform() async throws -> some IntentResult {
        if value {
            await MainActor.run {
                Task {
                    try? await TimerSyncManager.shared.startTimer(durationMinutes: 25)
                }
            }
        } else {
            await MainActor.run {
                Task {
                    try? await TimerSyncManager.shared.stopTimer()
                }
            }
        }

        return .result()
    }
}

// MARK: - Streak Display Control (iOS 18+)

/// Control Center display showing current streak
@available(iOS 18.0, *)
struct StreakDisplayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.refocus.streak",
            provider: StreakValueProvider()
        ) { value in
            ControlWidgetButton(action: OpenAppIntent()) {
                Label {
                    Text("\(value) day streak")
                } icon: {
                    Image(systemName: "flame.fill")
                }
            }
            .tint(.orange)
        }
        .displayName("Focus Streak")
        .description("View your current focus streak")
    }
}

@available(iOS 18.0, *)
struct StreakValueProvider: ControlValueProvider {
    var previewValue: Int { 7 }

    func currentValue() async throws -> Int {
        await MainActor.run {
            StatsManager.shared.currentStreak
        }
    }
}

@available(iOS 18.0, *)
struct OpenAppIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Open ReFocus"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

#endif
