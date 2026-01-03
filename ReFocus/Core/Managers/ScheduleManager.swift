import Foundation
import Combine

/// Manages recurring focus schedules
@MainActor
final class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()

    // MARK: - Published Properties

    @Published private(set) var schedules: [FocusSchedule] = []
    @Published private(set) var activeSchedule: FocusSchedule?
    @Published private(set) var isScheduleActive: Bool = false

    // MARK: - Private Properties

    private let schedulesKey = "focusSchedules"
    private var checkTask: Task<Void, Never>?

    // MARK: - Dependencies

    private var blockEnforcementManager: BlockEnforcementManager?

    // MARK: - Initialization

    private init() {
        loadSchedules()
        startScheduleChecking()
    }

    func configure(with enforcementManager: BlockEnforcementManager) {
        self.blockEnforcementManager = enforcementManager
    }

    // MARK: - Schedule Management

    func addSchedule(_ schedule: FocusSchedule) {
        schedules.append(schedule)
        saveSchedules()
    }

    func updateSchedule(_ schedule: FocusSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
            saveSchedules()
        }
    }

    func deleteSchedule(id: UUID) {
        schedules.removeAll { $0.id == id }
        saveSchedules()
    }

    func toggleSchedule(id: UUID) {
        if let index = schedules.firstIndex(where: { $0.id == id }) {
            schedules[index].isEnabled.toggle()
            saveSchedules()
            checkActiveSchedule()
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

        var foundActiveSchedule: FocusSchedule?

        for schedule in schedules where schedule.isEnabled {
            guard let weekday = currentWeekday,
                  schedule.days.contains(weekday) else {
                continue
            }

            if currentTime >= schedule.startTime && currentTime < schedule.endTime {
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
        } else if !isScheduleActive && wasActive {
            // Schedule just ended
            blockEnforcementManager?.stopEnforcement()
        }
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
    #endif
}
