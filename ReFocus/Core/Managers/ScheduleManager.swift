import Foundation
import Combine
#if os(iOS)
import DeviceActivity
#endif

/// Manages recurring focus schedules
@MainActor
final class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()

    // MARK: - Published Properties

    @Published private(set) var schedules: [FocusSchedule] = []
    @Published private(set) var activeSchedule: FocusSchedule?
    @Published private(set) var isScheduleActive: Bool = false

    /// Live-updating remaining time (updates every second when active)
    @Published private(set) var liveRemainingTime: TimeInterval = 0

    /// Time until next schedule starts (updates every minute when inactive)
    @Published private(set) var timeUntilNextSchedule: TimeInterval?

    /// Schedule that was ended early (for showing post-end options)
    @Published private(set) var endedSchedule: FocusSchedule?

    /// Whether a schedule is currently skipped/paused
    @Published private(set) var isScheduleSkipped: Bool = false

    /// Break mode - pauses schedule temporarily
    @Published private(set) var isOnBreak: Bool = false
    @Published private(set) var breakRemainingTime: TimeInterval = 0
    @Published private(set) var breakSchedule: FocusSchedule?
    @Published private(set) var breakDuration: TimeInterval = 0

    // MARK: - Private Properties

    private let schedulesKey = "focusSchedules"
    private var checkTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var breakTask: Task<Void, Never>?
    private var breakEndTime: Date?

    /// ID of schedule to skip until its window ends
    private var skippedScheduleId: UUID?
    /// Time when the skip expires (end of current schedule window)
    private var skipExpiresAt: Date?

    // MARK: - Dependencies

    private var blockEnforcementManager: BlockEnforcementManager?

    // MARK: - Initialization

    private init() {
        loadSchedules()
        #if DEBUG
        // Add test schedules if none exist
        if schedules.isEmpty {
            addTestSchedules()
        }
        #endif
        startScheduleChecking()

        // Register all schedules with DeviceActivityCenter for background enforcement
        #if os(iOS)
        registerSchedulesWithDeviceActivity()
        #endif
    }

    #if os(iOS)
    /// Register all enabled schedules with DeviceActivityCenter
    private func registerSchedulesWithDeviceActivity() {
        DeviceActivityScheduler.shared.registerAllSchedules(schedules)
    }
    #endif

    func configure(with enforcementManager: BlockEnforcementManager) {
        self.blockEnforcementManager = enforcementManager
    }

    // MARK: - Schedule Management

    func addSchedule(_ schedule: FocusSchedule) {
        schedules.append(schedule)
        saveSchedules()

        // Sync to server
        Task {
            try? await ScheduleSyncManager.shared.pushSchedule(schedule)
        }

        // Register with DeviceActivityCenter for background enforcement
        #if os(iOS)
        do {
            try DeviceActivityScheduler.shared.registerSchedule(schedule)
        } catch {
            print("Failed to register schedule with DeviceActivity: \(error)")
        }
        #endif
    }

    func updateSchedule(_ schedule: FocusSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
            saveSchedules()

            // Sync to server
            Task {
                try? await ScheduleSyncManager.shared.updateSchedule(schedule)
            }

            // Update DeviceActivityCenter registration
            #if os(iOS)
            do {
                try DeviceActivityScheduler.shared.updateSchedule(schedule)
            } catch {
                print("Failed to update schedule with DeviceActivity: \(error)")
            }
            #endif
        }
    }

    func deleteSchedule(id: UUID) {
        let schedule = schedules.first { $0.id == id }
        schedules.removeAll { $0.id == id }
        saveSchedules()

        // Sync to server
        if let schedule = schedule {
            Task {
                try? await ScheduleSyncManager.shared.deleteSchedule(schedule)
            }
        }

        // Unregister from DeviceActivityCenter
        #if os(iOS)
        DeviceActivityScheduler.shared.unregisterSchedule(id)
        #endif
    }

    func duplicateSchedule(id: UUID) {
        guard let schedule = schedules.first(where: { $0.id == id }) else { return }
        let duplicate = schedule.duplicate()
        addSchedule(duplicate)
    }

    func toggleSchedule(id: UUID) {
        if let index = schedules.firstIndex(where: { $0.id == id }) {
            schedules[index].isEnabled.toggle()
            saveSchedules()
            checkActiveSchedule()

            // Update DeviceActivityCenter
            #if os(iOS)
            do {
                try DeviceActivityScheduler.shared.updateSchedule(schedules[index])
            } catch {
                print("Failed to toggle schedule with DeviceActivity: \(error)")
            }
            #endif
        }
    }


        // MARK: - Schedule Checking

    private func startScheduleChecking() {
        checkTask?.cancel()
        checkTask = Task { @MainActor in
            while !Task.isCancelled {
                checkActiveSchedule()
                try? await Task.sleep(for: .seconds(30)) // Check every 30 seconds
            }
        }
    }

    func checkActiveSchedule() {
        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = Weekday(rawValue: calendar.component(.weekday, from: now))
        let currentTime = TimeComponents.from(date: now)

        // Check if skip has expired
        if let expiry = skipExpiresAt, now >= expiry {
            clearSkip()
        }

        var foundActiveSchedule: FocusSchedule?

        for schedule in schedules where schedule.isEnabled {
            guard let weekday = currentWeekday,
                  schedule.days.contains(weekday) else {
                continue
            }

            if currentTime >= schedule.startTime && currentTime < schedule.endTime {
                // Check if this schedule is currently skipped
                if schedule.id == skippedScheduleId {
                    continue // Skip this schedule
                }
                foundActiveSchedule = schedule
                break
            }
        }

        let wasActive = isScheduleActive
        activeSchedule = foundActiveSchedule
        isScheduleActive = foundActiveSchedule != nil

        // Handle enforcement changes
        if isScheduleActive && !wasActive {
            // Schedule just became active
            blockEnforcementManager?.startEnforcement()
            startCountdownTimer()
        } else if !isScheduleActive && wasActive {
            // Schedule just ended
            blockEnforcementManager?.stopEnforcement()
            stopCountdownTimer()
        }

        // Update time until next schedule when not active
        if !isScheduleActive {
            updateTimeUntilNextSchedule()
        }
    }

    // MARK: - Live Countdown Timer

    private func startCountdownTimer() {
        stopCountdownTimer()
        countdownTask = Task { @MainActor in
            while !Task.isCancelled && isScheduleActive {
                if let remaining = remainingTimeInSchedule {
                    liveRemainingTime = remaining
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopCountdownTimer() {
        countdownTask?.cancel()
        countdownTask = nil
        liveRemainingTime = 0
    }

    private func updateTimeUntilNextSchedule() {
        guard let nextSchedule = findNextEnabledSchedule() else {
            timeUntilNextSchedule = nil
            return
        }

        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = Weekday(rawValue: calendar.component(.weekday, from: now))
        let currentTime = TimeComponents.from(date: now)

        // Check if it's today
        if let weekday = currentWeekday,
           nextSchedule.days.contains(weekday),
           nextSchedule.startTime > currentTime {
            let nowComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
            let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
            let nowSeconds = nowMinutes * 60 + (nowComponents.second ?? 0)
            let targetSeconds = nextSchedule.startTime.totalMinutes * 60
            timeUntilNextSchedule = TimeInterval(targetSeconds - nowSeconds)
            return
        }

        // Find the next day
        for dayOffset in 1...7 {
            let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            let futureWeekday = Weekday(rawValue: calendar.component(.weekday, from: futureDate))

            if let weekday = futureWeekday, nextSchedule.days.contains(weekday) {
                let startOfToday = calendar.startOfDay(for: now)
                let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday)!
                let targetDate = calendar.date(bySettingHour: nextSchedule.startTime.hour,
                                               minute: nextSchedule.startTime.minute,
                                               second: 0,
                                               of: targetDay)!
                timeUntilNextSchedule = targetDate.timeIntervalSince(now)
                return
            }
        }

        timeUntilNextSchedule = nil
    }

    /// Find the next enabled schedule
    func findNextEnabledSchedule() -> FocusSchedule? {
        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = Weekday(rawValue: calendar.component(.weekday, from: now))
        let currentTime = TimeComponents.from(date: now)

        let enabledSchedules = schedules.filter { $0.isEnabled }

        // Look for next schedule today
        for schedule in enabledSchedules {
            if let weekday = currentWeekday,
               schedule.days.contains(weekday),
               schedule.startTime > currentTime {
                return schedule
            }
        }

        // Look for schedule on upcoming days
        for dayOffset in 1...7 {
            let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            let futureWeekday = Weekday(rawValue: calendar.component(.weekday, from: futureDate))

            for schedule in enabledSchedules {
                if let weekday = futureWeekday, schedule.days.contains(weekday) {
                    return schedule
                }
            }
        }

        return nil
    }

    // MARK: - Manual Schedule Control

    /// Manually end an active schedule early
    func endScheduleEarly() {
        guard isScheduleActive, let schedule = activeSchedule else { return }

        // Store the ended schedule for UI to show options
        endedSchedule = schedule

        // Calculate when the current schedule window ends
        let calendar = Calendar.current
        let now = Date()
        let endTimeToday = calendar.date(
            bySettingHour: schedule.endTime.hour,
            minute: schedule.endTime.minute,
            second: 0,
            of: now
        ) ?? now

        // Set up skip until the schedule window ends
        skippedScheduleId = schedule.id
        skipExpiresAt = endTimeToday
        isScheduleSkipped = true

        // Stop enforcement
        blockEnforcementManager?.stopEnforcement()

        // Stop countdown
        stopCountdownTimer()

        // Clear active schedule
        activeSchedule = nil
        isScheduleActive = false

        // Update time until next
        updateTimeUntilNextSchedule()
    }

    /// Resume a schedule that was ended early
    func resumeSchedule() {
        clearSkip()
        endedSchedule = nil
        checkActiveSchedule()
    }

    /// Clear the schedule skip (called when skip expires or user resumes)
    private func clearSkip() {
        skippedScheduleId = nil
        skipExpiresAt = nil
        isScheduleSkipped = false
    }

    /// Clear the ended schedule info (called when user dismisses the post-end view)
    func clearEndedSchedule() {
        endedSchedule = nil
    }

    /// Get remaining time until skip expires (for UI)
    var skipRemainingTime: TimeInterval? {
        guard let expiry = skipExpiresAt else { return nil }
        let remaining = expiry.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    /// Get the schedule that is currently skipped/paused
    var skippedSchedule: FocusSchedule? {
        guard let id = skippedScheduleId else { return nil }
        return schedules.first { $0.id == id }
    }

    // MARK: - Break Mode

    /// Start a break from the current schedule
    /// When break ends, automatically resume the schedule
    func startBreak(duration: TimeInterval, for schedule: FocusSchedule) {
        // Store the schedule we're breaking from
        breakSchedule = schedule
        breakDuration = duration
        breakRemainingTime = duration
        breakEndTime = Date().addingTimeInterval(duration)
        isOnBreak = true

        // Keep the skip active during break (blocking is paused)
        // Don't call clearSkip() here

        // Start break countdown timer
        breakTask?.cancel()
        breakTask = Task { @MainActor in
            while !Task.isCancelled && isOnBreak {
                if let endTime = breakEndTime {
                    let remaining = endTime.timeIntervalSinceNow
                    if remaining <= 0 {
                        // Break is over, resume schedule
                        endBreak()
                        break
                    }
                    breakRemainingTime = remaining
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// End the break and resume the schedule
    func endBreak() {
        breakTask?.cancel()
        breakTask = nil

        let scheduleToResume = breakSchedule

        // Clear break state
        isOnBreak = false
        breakRemainingTime = 0
        breakDuration = 0
        breakEndTime = nil
        breakSchedule = nil

        // Resume the schedule if it's still in its time window
        if scheduleToResume != nil {
            clearSkip()
            endedSchedule = nil
            checkActiveSchedule()
        }
    }

    /// Cancel break without resuming schedule
    func cancelBreak() {
        breakTask?.cancel()
        breakTask = nil

        isOnBreak = false
        breakRemainingTime = 0
        breakDuration = 0
        breakEndTime = nil
        breakSchedule = nil
    }

    /// Manually start a schedule now (even if not scheduled)
    func startScheduleNow(_ schedule: FocusSchedule) {
        activeSchedule = schedule
        isScheduleActive = true
        blockEnforcementManager?.startEnforcement()
        startCountdownTimer()
    }

    // Calculate remaining time in current schedule
    var remainingTimeInSchedule: TimeInterval? {
        guard let schedule = activeSchedule else { return nil }

        let now = Date()
        let calendar = Calendar.current

        var endComponents = calendar.dateComponents([.year, .month, .day], from: now)
        endComponents.hour = schedule.endTime.hour
        endComponents.minute = schedule.endTime.minute

        guard let endDate = calendar.date(from: endComponents) else { return nil }
        return endDate.timeIntervalSince(now)
    }

    // MARK: - Persistence

    private func loadSchedules() {
        if let data = UserDefaults.standard.data(forKey: schedulesKey),
           let decoded = try? JSONDecoder().decode([FocusSchedule].self, from: data) {
            schedules = decoded
        }
    }

    private func saveSchedules() {
        if let data = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(data, forKey: schedulesKey)
        }
    }

    // MARK: - Preview Helpers

    #if DEBUG
    static var preview: ScheduleManager {
        let manager = ScheduleManager()
        manager.schedules = [
            FocusSchedule(
                id: UUID(),
                name: "Work Hours",
                startTime: TimeComponents(hour: 9, minute: 0),
                endTime: TimeComponents(hour: 17, minute: 0),
                days: Set(Weekday.weekdays),
                isEnabled: true,
                isStrictMode: false,
                focusModeId: nil,
                themeGradient: .ocean
            ),
            FocusSchedule(
                id: UUID(),
                name: "Morning Focus",
                startTime: TimeComponents(hour: 6, minute: 0),
                endTime: TimeComponents(hour: 8, minute: 0),
                days: Set(Weekday.allCases),
                isEnabled: false,
                isStrictMode: true,
                focusModeId: nil,
                themeGradient: .amber
            )
        ]
        return manager
    }

    /// Add test schedules for demonstrating the circular clock
    func addTestSchedules() {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let today = Weekday(rawValue: calendar.component(.weekday, from: now)) ?? .monday

        // Clear existing schedules
        schedules.removeAll()

        // Schedule 1: Currently active (covers now)
        let activeStart = max(0, currentHour - 1)
        let activeEnd = min(23, currentHour + 2)
        schedules.append(FocusSchedule(
            id: UUID(),
            name: "Current Focus",
            startTime: TimeComponents(hour: activeStart, minute: 0),
            endTime: TimeComponents(hour: activeEnd, minute: 0),
            days: Set([today]),
            isEnabled: true,
            isStrictMode: false,
            focusModeId: nil,
            themeGradient: .violet
        ))

        // Schedule 2: Morning block
        schedules.append(FocusSchedule(
            id: UUID(),
            name: "Morning",
            startTime: TimeComponents(hour: 6, minute: 0),
            endTime: TimeComponents(hour: 9, minute: 0),
            days: Set([today]),
            isEnabled: true,
            isStrictMode: false,
            focusModeId: nil,
            themeGradient: .amber
        ))

        // Schedule 3: Afternoon block
        schedules.append(FocusSchedule(
            id: UUID(),
            name: "Afternoon",
            startTime: TimeComponents(hour: 14, minute: 0),
            endTime: TimeComponents(hour: 18, minute: 0),
            days: Set([today]),
            isEnabled: true,
            isStrictMode: false,
            focusModeId: nil,
            themeGradient: .teal
        ))

        // Schedule 4: Evening block
        schedules.append(FocusSchedule(
            id: UUID(),
            name: "Evening",
            startTime: TimeComponents(hour: 20, minute: 0),
            endTime: TimeComponents(hour: 22, minute: 0),
            days: Set([today]),
            isEnabled: true,
            isStrictMode: false,
            focusModeId: nil,
            themeGradient: .rose
        ))

        saveSchedules()
        checkActiveSchedule()
    }
    #endif
}
