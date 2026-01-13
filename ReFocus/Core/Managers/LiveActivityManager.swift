import Foundation
#if os(iOS)
@preconcurrency import ActivityKit
#endif

/// Manages Live Activities for focus sessions (iOS 16.2+)
@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    #if os(iOS)
    @available(iOS 16.1, *)
    private var currentActivityId: String?
    #endif

    @Published private(set) var isLiveActivityActive: Bool = false

    private init() {}

    // MARK: - Live Activity Control

    /// Start a Live Activity for a focus session
    func startLiveActivity(
        sessionId: UUID,
        durationMinutes: Int,
        modeName: String,
        modeIcon: String,
        endTime: Date
    ) {
        #if os(iOS)
        guard #available(iOS 16.2, *) else { return }

        // Check if Live Activities are enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Log.LiveActivity.debug("Live Activities not enabled")
            return
        }

        Task { @MainActor in
            // End any existing activity first
            await endAllActivitiesInternal()

            let attributes = FocusActivityAttributes(
                sessionId: sessionId,
                totalDurationMinutes: durationMinutes,
                focusModeIcon: modeIcon
            )

            let remainingSeconds = Int(endTime.timeIntervalSinceNow)
            let initialState = FocusActivityAttributes.ContentState(
                remainingSeconds: max(0, remainingSeconds),
                isPaused: false,
                modeName: modeName,
                endTime: endTime
            )

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: initialState, staleDate: endTime),
                    pushType: nil
                )
                self.currentActivityId = activity.id
                self.isLiveActivityActive = true
                Log.LiveActivity.info("Started Live Activity: \(activity.id)")
            } catch {
                Log.LiveActivity.error("Failed to start Live Activity", error: error)
            }
        }
        #endif
    }

    /// Update the Live Activity with new state
    func updateLiveActivity(
        remainingSeconds: Int,
        isPaused: Bool,
        modeName: String,
        endTime: Date
    ) {
        #if os(iOS)
        guard #available(iOS 16.2, *) else { return }
        guard let activityId = currentActivityId else { return }

        let updatedState = FocusActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            isPaused: isPaused,
            modeName: modeName,
            endTime: endTime
        )

        let content = ActivityContent(state: updatedState, staleDate: endTime)

        Task {
            // Find and update the activity
            for activity in Activity<FocusActivityAttributes>.activities where activity.id == activityId {
                await activity.update(content)
                break
            }
        }
        #endif
    }

    /// End the current Live Activity
    func endLiveActivity(completed: Bool = true) async {
        #if os(iOS)
        guard #available(iOS 16.2, *) else { return }
        guard let activityId = currentActivityId else { return }

        let finalState = FocusActivityAttributes.ContentState(
            remainingSeconds: 0,
            isPaused: false,
            modeName: completed ? "Session Complete" : "Session Ended",
            endTime: Date()
        )

        let content = ActivityContent(state: finalState, staleDate: nil)

        // Find and end the activity
        for activity in Activity<FocusActivityAttributes>.activities where activity.id == activityId {
            await activity.end(content, dismissalPolicy: .immediate)
            break
        }

        currentActivityId = nil
        isLiveActivityActive = false
        Log.LiveActivity.info("Ended Live Activity")
        #endif
    }

    /// End all activities (cleanup) - internal version
    private func endAllActivitiesInternal() async {
        #if os(iOS)
        guard #available(iOS 16.2, *) else { return }

        for activity in Activity<FocusActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        currentActivityId = nil
        isLiveActivityActive = false
        #endif
    }

    /// End all activities (cleanup) - public version
    func endAllActivities() async {
        await endAllActivitiesInternal()
    }

    // MARK: - State Query

    /// Check if there's an active Live Activity
    func hasActiveActivity() -> Bool {
        #if os(iOS)
        guard #available(iOS 16.2, *) else { return false }
        return !Activity<FocusActivityAttributes>.activities.isEmpty
        #else
        return false
        #endif
    }

    /// Check if Live Activities are available and enabled
    func areLiveActivitiesEnabled() -> Bool {
        #if os(iOS)
        guard #available(iOS 16.2, *) else { return false }
        return ActivityAuthorizationInfo().areActivitiesEnabled
        #else
        return false
        #endif
    }
}
