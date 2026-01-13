import Foundation
import Supabase
import Combine

/// Manages real-time timer synchronization via Supabase Realtime
@MainActor
final class TimerSyncManager: ObservableObject {
    static let shared = TimerSyncManager()

    // MARK: - Published State

    @Published private(set) var timerState: SharedTimerState?
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var syncError: Error?

    // MARK: - Local Timer for UI Updates

    @Published private(set) var displayRemainingTime: TimeInterval = 0
    private var localTimerTask: Task<Void, Never>?

    // MARK: - Callbacks for Enforcement

    var onTimerActivated: ((SharedTimerState) -> Void)?
    var onTimerDeactivated: (() -> Void)?
    var onTimerUpdated: ((SharedTimerState) -> Void)?

    // MARK: - Current Session Info (for Live Activity)

    private var currentModeName: String = "Focus"
    private var currentModeIcon: String = "brain.head.profile"

    // MARK: - Private

    private var realtimeChannel: RealtimeChannelV2?
    private let supabase = SupabaseManager.shared
    private let liveActivityManager = LiveActivityManager.shared

    private init() {}

    // MARK: - Subscription

    /// Subscribe to timer state changes for the current user
    func subscribe() async throws {
        let userId = try supabase.requireUserId()

        // First, fetch current state
        await fetchCurrentState(userId: userId)

        // Then subscribe to realtime changes
        let channel = supabase.client.realtimeV2.channel("timer-\(userId.uuidString)")

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "timer_states",
            filter: "user_id=eq.\(userId.uuidString)"
        )

        await channel.subscribe()

        Task {
            for await change in changes {
                await handleRealtimeChange(change)
            }
        }

        realtimeChannel = channel
        isConnected = true
    }

    /// Unsubscribe from realtime updates
    func unsubscribe() async {
        await realtimeChannel?.unsubscribe()
        realtimeChannel = nil
        isConnected = false
        stopLocalTimer()
    }

    // MARK: - Timer Control

    /// Start a new timer (syncs to all devices)
    func startTimer(duration: TimeInterval, modeName: String? = nil, modeIcon: String? = nil) async throws {
        let userId = try supabase.requireUserId()
        let deviceId = DeviceInfo.currentDeviceId

        // Store mode info for Live Activity
        if let name = modeName {
            currentModeName = name
        }
        if let icon = modeIcon {
            currentModeIcon = icon
        }

        var newState = timerState ?? SharedTimerState.inactive(userId: userId, deviceId: deviceId)
        newState.activate(duration: duration, deviceId: deviceId)

        // Upsert to Supabase
        try await supabase.client.from("timer_states")
            .upsert(newState, onConflict: "user_id")
            .execute()

        // Optimistic update
        timerState = newState
        startLocalTimer()

        // Notify enforcement layer
        onTimerActivated?(newState)

        // Update widget data
        WidgetDataManager.shared.updateSessionState(isActive: true, endTime: newState.endTime)

        // Start Live Activity (iOS 16.2+)
        if let endTime = newState.endTime {
            liveActivityManager.startLiveActivity(
                sessionId: newState.id,
                durationMinutes: Int(duration / 60),
                modeName: currentModeName,
                modeIcon: currentModeIcon,
                endTime: endTime
            )
        }
    }

    /// Start a new timer with duration in minutes (syncs to all devices)
    func startTimer(durationMinutes: Int, modeName: String? = nil, modeIcon: String? = nil) async throws {
        try await startTimer(duration: TimeInterval(durationMinutes * 60), modeName: modeName, modeIcon: modeIcon)
    }

    /// Start a timer with a focus mode (syncs to all devices)
    func startTimer(with mode: FocusMode) async throws {
        try await startTimer(
            duration: mode.duration,
            modeName: mode.name,
            modeIcon: mode.icon
        )
    }

    /// Stop the current timer (syncs to all devices)
    func stopTimer(completed: Bool = true) async throws {
        guard var state = timerState, state.isActive else { return }

        let deviceId = DeviceInfo.currentDeviceId
        state.deactivate(deviceId: deviceId)

        // Update in Supabase
        try await supabase.client.from("timer_states")
            .update(state)
            .eq("user_id", value: state.userId.uuidString)
            .execute()

        // Optimistic update
        timerState = state
        stopLocalTimer()

        // Notify enforcement layer
        onTimerDeactivated?()

        // Update widget data
        WidgetDataManager.shared.updateSessionState(isActive: false, endTime: nil)

        // End Live Activity
        await liveActivityManager.endLiveActivity(completed: completed)
    }

    /// Extend the current timer by additional seconds
    func extendTimer(by seconds: TimeInterval) async throws {
        guard var state = timerState, state.isActive else { return }

        let deviceId = DeviceInfo.currentDeviceId
        state.extend(by: seconds, deviceId: deviceId)

        // Update in Supabase
        try await supabase.client.from("timer_states")
            .update(state)
            .eq("user_id", value: state.userId.uuidString)
            .execute()

        // Optimistic update
        timerState = state

        // Notify enforcement layer
        onTimerUpdated?(state)

        // Update Live Activity with new end time
        if let remaining = state.remainingTime, let endTime = state.endTime {
            liveActivityManager.updateLiveActivity(
                remainingSeconds: Int(remaining),
                isPaused: false,
                modeName: currentModeName,
                endTime: endTime
            )
        }

        // Update widget data with new end time
        WidgetDataManager.shared.updateSessionState(isActive: true, endTime: state.endTime)
    }

    // MARK: - Private Methods

    private func fetchCurrentState(userId: UUID) async {
        do {
            let response: [SharedTimerState] = try await supabase.client
                .from("timer_states")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            if let state = response.first {
                timerState = state

                if state.isActive && !state.hasExpired {
                    startLocalTimer()
                    onTimerActivated?(state)
                } else if state.isActive && state.hasExpired {
                    // Timer expired while we were offline, stop it
                    try? await stopTimer()
                }
            }
        } catch {
            syncError = error
        }
    }

    private func handleRealtimeChange(_ change: AnyAction) async {
        switch change {
        case .insert(let action):
            if let state = try? action.decodeRecord(as: SharedTimerState.self, decoder: JSONDecoder()) {
                await handleStateUpdate(state)
            }
        case .update(let action):
            if let state = try? action.decodeRecord(as: SharedTimerState.self, decoder: JSONDecoder()) {
                await handleStateUpdate(state)
            }
        case .delete:
            timerState = nil
            stopLocalTimer()
            onTimerDeactivated?()
            // End Live Activity when timer is deleted
            await liveActivityManager.endLiveActivity(completed: false)
        default:
            break
        }
    }

    private func handleStateUpdate(_ state: SharedTimerState) async {
        let wasActive = timerState?.isActive ?? false
        timerState = state

        if state.isActive && !state.hasExpired {
            startLocalTimer()
            if !wasActive {
                onTimerActivated?(state)
                // Start Live Activity when timer activated from another device
                if let endTime = state.endTime, let duration = state.plannedDurationSeconds {
                    liveActivityManager.startLiveActivity(
                        sessionId: state.id,
                        durationMinutes: duration / 60,
                        modeName: currentModeName,
                        modeIcon: currentModeIcon,
                        endTime: endTime
                    )
                }
            } else {
                onTimerUpdated?(state)
                // Update Live Activity when timer extended from another device
                if let remaining = state.remainingTime, let endTime = state.endTime {
                    liveActivityManager.updateLiveActivity(
                        remainingSeconds: Int(remaining),
                        isPaused: false,
                        modeName: currentModeName,
                        endTime: endTime
                    )
                }
            }
        } else {
            stopLocalTimer()
            if wasActive {
                onTimerDeactivated?()
                // End Live Activity when timer stopped from another device
                await liveActivityManager.endLiveActivity(completed: state.hasExpired)
            }
        }
    }

    // MARK: - Local Timer for Display

    private func startLocalTimer() {
        stopLocalTimer()

        localTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self,
                      let state = self.timerState,
                      state.isActive,
                      let remaining = state.remainingTime else {
                    break
                }

                self.displayRemainingTime = remaining

                if remaining <= 0 {
                    // Timer expired
                    try? await self.stopTimer()
                    break
                }

                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms for smooth updates
            }
        }
    }

    private func stopLocalTimer() {
        localTimerTask?.cancel()
        localTimerTask = nil
        displayRemainingTime = 0
    }
}
