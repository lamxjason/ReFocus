import SwiftUI
#if os(iOS)
import FamilyControls
import ManagedSettings
#endif

enum FocusViewMode: String, CaseIterable {
    case timer = "Timer"
    case schedule = "Schedule"
}

struct FocusSessionView: View {
    @EnvironmentObject var timerSyncManager: TimerSyncManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var websiteSyncManager: WebsiteSyncManager
    @EnvironmentObject var blockEnforcementManager: BlockEnforcementManager
    @StateObject private var premiumManager = PremiumManager.shared
    @StateObject private var modeManager = FocusModeManager.shared
    @StateObject private var scheduleManager = ScheduleManager.shared
    @StateObject private var hardModeManager = HardModeManager.shared
    @StateObject private var regretManager = RegretPreventionManager.shared
    @StateObject private var companionManager = DeepWorkCompanionManager.shared
    private let statsManager = StatsManager.shared

    // View mode binding to sync with parent
    @Binding var viewModeString: String
    private var viewMode: FocusViewMode {
        get { FocusViewMode(rawValue: viewModeString) ?? .timer }
    }

    init(viewModeBinding: Binding<String>) {
        self._viewModeString = viewModeBinding
    }

    @State private var selectedDuration: TimeInterval = 25 * 60
    @State private var showingDurationPicker = false
    @State private var showingModesPicker = false
    @State private var showingScheduleList = false
    @State private var showingPaywall = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false

    // Local timer fallback when not syncing
    @State private var localTimerActive = false
    @State private var localTimerStart: Date?
    @State private var localTimerEnd: Date?
    @State private var localTimerRemaining: TimeInterval = 0
    @State private var localTimerTask: Task<Void, Never>?
    @State private var sessionPlannedDuration: TimeInterval = 0

    // Strict mode state for current session
    @State private var sessionIsStrict = false

    // Strict mode confirmation
    @State private var showingStrictConfirmation = false

    // End session delay
    @State private var showingEndDelay = false
    @State private var showingHardModeDelay = false
    @State private var showingSessionReview = false

    // Timer dial rotation tracking
    @State private var lastDragLocation: CGPoint?

    var body: some View {
        ZStack {
            // Pure black background
            DesignSystem.Colors.background
                .ignoresSafeArea()

            // Subtle ambient mode gradient
            ambientModeGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: modeColor)

            VStack(spacing: 0) {
                // Mode toggle (Timer vs Schedule) - only when not active
                if !isTimerActive && !scheduleManager.isScheduleActive {
                    viewModeToggle
                        .padding(.top, DesignSystem.Spacing.sm)
                        .padding(.bottom, DesignSystem.Spacing.md)
                }

                Spacer()

                // Shared ring position (always in center)
                timerRingArea

                Spacer()
                    .frame(height: DesignSystem.Spacing.lg)

                // Mode-specific content below ring
                ZStack {
                    timerBelowRingContent
                        .opacity(viewMode == .timer ? 1 : 0)

                    scheduleBelowRingContent
                        .opacity(viewMode == .schedule ? 1 : 0)
                }
                .frame(minHeight: 200)
                .animation(.easeInOut(duration: 0.2), value: viewMode)

                Spacer()
            }

        }
        .sheet(isPresented: $showingDurationPicker) {
            DurationPickerView(duration: $selectedDuration)
        }
        .sheet(isPresented: $showingModesPicker) {
            FocusModesView()
        }
        .sheet(isPresented: $showingScheduleList) {
            ScheduleListView()
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .sheet(isPresented: $showingEndDelay) {
            EndSessionDelayView(
                onConfirm: {
                    showingEndDelay = false
                    performStopSession()
                },
                onCancel: {
                    showingEndDelay = false
                },
                modeColor: modeColor
            )
        }
        .sheet(isPresented: $showingHardModeDelay) {
            EmergencyExitView(
                sessionId: companionManager.currentSessionId ?? UUID(),
                focusedTime: sessionFocusedTime,
                remainingTime: currentRemainingTime,
                onConfirmExit: {
                    showingHardModeDelay = false
                    performStopSession()
                },
                onCancel: {
                    showingHardModeDelay = false
                },
                modeColor: modeColor
            )
        }
        .sheet(isPresented: $showingSessionReview) {
            SessionReviewView(modeColor: modeColor)
        }
        .confirmationDialog(
            "Lock Session",
            isPresented: $showingStrictConfirmation,
            titleVisibility: .visible
        ) {
            Button("Confirm Lock", role: .destructive) {
                confirmStartStrict()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This session cannot be ended early. Duration: \(formatDuration(selectedDuration)).")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        GeometryReader { geometry in
            let segmentWidth = (geometry.size.width - 8) / 2

            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(DesignSystem.Colors.backgroundCard)

                // Sliding selection indicator
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [modeColor, modeColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: segmentWidth)
                    .offset(x: viewMode == .timer ? 4 : segmentWidth + 4)

                // Buttons
                HStack(spacing: 0) {
                    ForEach(FocusViewMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModeString = mode.rawValue
                            }
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: mode == .timer ? "timer" : "calendar.badge.clock")
                                    .font(.system(size: 14))

                                Text(mode.rawValue)
                                    .font(DesignSystem.Typography.captionMedium)
                            }
                            .foregroundStyle(viewMode == mode ? .white : DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: geometry.size.height)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, DesignSystem.Spacing.xl)
    }

    // MARK: - Shared Ring Area

    private var timerRingArea: some View {
        ZStack {
            // Background ring (always visible)
            Circle()
                .stroke(DesignSystem.Colors.backgroundCard, lineWidth: 8)
                .frame(width: DesignSystem.Sizes.timerRingSize, height: DesignSystem.Sizes.timerRingSize)

            // Timer mode ring content
            Group {
                if viewMode == .timer {
                    timerRingContent
                } else {
                    scheduleRingContent
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewMode)
        }
        .frame(width: DesignSystem.Sizes.timerRingSize, height: DesignSystem.Sizes.timerRingSize)
    }

    private var timerRingContent: some View {
        ZStack {
            // Progress ring
            Circle()
                .trim(from: 0, to: isTimerActive ? currentProgress : 1.0)
                .stroke(modeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: DesignSystem.Sizes.timerRingSize, height: DesignSystem.Sizes.timerRingSize)
                .rotationEffect(.degrees(-90))

            // Time display
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(remainingTimeString)
                    .font(DesignSystem.Typography.timerLarge)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(isTimerActive ? "focusing" : "ready")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(2)
            }
        }
    }

    private var scheduleRingContent: some View {
        ZStack {
            if let activeSchedule = scheduleManager.activeSchedule {
                // Active schedule progress
                Circle()
                    .trim(from: 0, to: scheduleProgress)
                    .stroke(activeSchedule.primaryColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: DesignSystem.Sizes.timerRingSize, height: DesignSystem.Sizes.timerRingSize)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: DesignSystem.Spacing.xs) {
                    if let remaining = scheduleManager.remainingTimeInSchedule {
                        Text(formatScheduleRemaining(remaining))
                            .font(DesignSystem.Typography.timerLarge)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .monospacedDigit()
                    }

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if activeSchedule.isStrictMode {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(activeSchedule.primaryColor)
                        }
                        Text("scheduled")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .textCase(.uppercase)
                            .tracking(2)
                    }
                }
            } else {
                // Free time display
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text("free time")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(2)
                }
            }
        }
    }

    // MARK: - Timer Below Ring Content

    private var timerBelowRingContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Mode selector (when not active)
            if !isTimerActive {
                modeSelector
            }

            // Strict mode warning when active
            if isTimerActive && sessionIsStrict {
                strictModeActiveIndicator
            }

            // Main Action Button
            actionButton
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.sm)
        }
    }

    // MARK: - Schedule Below Ring Content

    @State private var selectedScheduleId: UUID?

    private var scheduleBelowRingContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Schedule selector (like mode selector)
            if !scheduleManager.schedules.isEmpty {
                scheduleSelector
            }

            // Blocked content info for selected schedule
            scheduleBlockedContentRow

            // Action button (Create or Manage)
            Button {
                if scheduleManager.schedules.isEmpty {
                    showingScheduleList = true
                } else {
                    showingScheduleList = true
                }
            } label: {
                Text(scheduleManager.schedules.isEmpty ? "Create Schedule" : "Manage Schedules")
            }
            .buttonStyle(ColoredPrimaryButtonStyle(color: scheduleAccentColor))
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.sm)
        }
    }

    private var scheduleSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(scheduleManager.schedules) { schedule in
                    SchedulePill(
                        schedule: schedule,
                        isSelected: selectedScheduleId == schedule.id || (selectedScheduleId == nil && schedule.id == scheduleManager.activeSchedule?.id),
                        isActive: schedule.id == scheduleManager.activeSchedule?.id,
                        onTap: {
                            withAnimation(DesignSystem.Animation.quick) {
                                selectedScheduleId = schedule.id
                            }
                        },
                        onEdit: {
                            showingScheduleList = true
                        }
                    )
                }

                // Add new schedule button
                Button {
                    showingScheduleList = true
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background {
                        Capsule()
                            .fill(DesignSystem.Colors.backgroundCard)
                            .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }

    private var selectedSchedule: FocusSchedule? {
        if let id = selectedScheduleId {
            return scheduleManager.schedules.first { $0.id == id }
        }
        return scheduleManager.activeSchedule ?? scheduleManager.schedules.first
    }

    private var scheduleBlockedContentRow: some View {
        let schedule = selectedSchedule
        let scheduleColor = schedule?.primaryColor ?? scheduleAccentColor

        return HStack(spacing: DesignSystem.Spacing.lg) {
            // Schedule time info
            if let schedule = schedule {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .foregroundStyle(scheduleColor.opacity(0.7))

                    Text(schedule.timeRangeDescription)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundStyle(scheduleColor.opacity(0.7))

                    Text(schedule.daysDescription)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            } else {
                Text("No schedules")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
    }

    private var scheduleRingDisplay: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.Colors.backgroundCard, lineWidth: 8)
                .frame(width: DesignSystem.Sizes.timerRingSize, height: DesignSystem.Sizes.timerRingSize)

            if let activeSchedule = scheduleManager.activeSchedule {
                // Active schedule - show progress
                Circle()
                    .trim(from: 0, to: scheduleProgress)
                    .stroke(activeSchedule.primaryColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: DesignSystem.Sizes.timerRingSize, height: DesignSystem.Sizes.timerRingSize)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: DesignSystem.Spacing.xs) {
                    if let remaining = scheduleManager.remainingTimeInSchedule {
                        Text(formatScheduleRemaining(remaining))
                            .font(DesignSystem.Typography.timerLarge)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .monospacedDigit()
                    }

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if activeSchedule.isStrictMode {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(activeSchedule.primaryColor)
                        }
                        Text("scheduled")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .textCase(.uppercase)
                            .tracking(2)
                    }
                }
            } else {
                // Free time - show calm state
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text("free time")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(2)
                }
            }
        }
    }

    private var scheduleInfoArea: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if let activeSchedule = scheduleManager.activeSchedule {
                // Active schedule info
                Text(activeSchedule.name)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Until \(activeSchedule.endTime.formatted)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            } else if let nextSchedule = findNextSchedule() {
                // Next schedule info
                Text("Next: \(nextSchedule.name)")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(formatNextScheduleTime(nextSchedule))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            } else if scheduleManager.schedules.isEmpty {
                // Empty state hint
                Text("No schedules yet")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Text("Create one to automate your focus")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            } else {
                // Has schedules but none upcoming
                Text("No upcoming schedules")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                Text("All schedules are disabled")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .frame(height: 80) // Fixed height to match mode selector area
    }

    private var scheduleEmptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(scheduleAccentColor)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Schedule Your Focus")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Set recurring times to automatically block distractions. Perfect for work hours or daily routines.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
    }

    private func activeScheduleDisplay(_ schedule: FocusSchedule) -> some View {
        let scheduleColor = schedule.primaryColor

        return VStack(spacing: DesignSystem.Spacing.lg) {
            // Progress ring for schedule
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.backgroundCard, lineWidth: 8)
                    .frame(width: DesignSystem.Sizes.timerRingSize, height: DesignSystem.Sizes.timerRingSize)

                Circle()
                    .trim(from: 0, to: scheduleProgress)
                    .stroke(scheduleColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: DesignSystem.Sizes.timerRingSize, height: DesignSystem.Sizes.timerRingSize)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: DesignSystem.Spacing.xs) {
                    if let remaining = scheduleManager.remainingTimeInSchedule {
                        Text(formatScheduleRemaining(remaining))
                            .font(DesignSystem.Typography.timerLarge)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .monospacedDigit()
                    }

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if schedule.isStrictMode {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(scheduleColor)
                        }

                        Text("scheduled")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .textCase(.uppercase)
                            .tracking(2)
                    }
                }
            }

            // Schedule name
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(schedule.name)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Until \(schedule.endTime.formatted)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
    }

    private var nextScheduleDisplay: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Calm state - no active schedule
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.backgroundCard, lineWidth: 8)
                    .frame(width: DesignSystem.Sizes.timerRingSize, height: DesignSystem.Sizes.timerRingSize)

                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text("free time")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(2)
                }
            }

            // Next schedule info
            if let nextSchedule = findNextSchedule() {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Next: \(nextSchedule.name)")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text(formatNextScheduleTime(nextSchedule))
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
    }

    private var scheduleProgress: Double {
        guard let schedule = scheduleManager.activeSchedule,
              let remaining = scheduleManager.remainingTimeInSchedule else {
            return 0
        }

        let totalMinutes = Double(schedule.endTime.totalMinutes - schedule.startTime.totalMinutes)
        let remainingMinutes = remaining / 60.0
        return 1.0 - (remainingMinutes / totalMinutes)
    }

    private func formatScheduleRemaining(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func findNextSchedule() -> FocusSchedule? {
        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = Weekday(rawValue: calendar.component(.weekday, from: now))
        let currentTime = TimeComponents.from(date: now)

        // Find enabled schedules
        let enabledSchedules = scheduleManager.schedules.filter { $0.isEnabled }

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

    private func formatNextScheduleTime(_ schedule: FocusSchedule) -> String {
        let now = Date()
        let calendar = Calendar.current
        let currentWeekday = Weekday(rawValue: calendar.component(.weekday, from: now))
        let currentTime = TimeComponents.from(date: now)

        // Check if it's today
        if let weekday = currentWeekday,
           schedule.days.contains(weekday),
           schedule.startTime > currentTime {
            return "Today at \(schedule.startTime.formatted)"
        }

        // Find the next day
        for dayOffset in 1...7 {
            let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            let futureWeekday = Weekday(rawValue: calendar.component(.weekday, from: futureDate))

            if let weekday = futureWeekday, schedule.days.contains(weekday) {
                if dayOffset == 1 {
                    return "Tomorrow at \(schedule.startTime.formatted)"
                } else {
                    return "\(weekday.shortName) at \(schedule.startTime.formatted)"
                }
            }
        }

        return schedule.startTime.formatted
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Gradient mode pills (Opal-inspired)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(modeManager.modes) { mode in
                        ModePill(
                            mode: mode,
                            isSelected: modeManager.selectedModeId == mode.id
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                modeManager.selectMode(mode)
                                selectedDuration = mode.duration
                            }
                        }
                    }

                    // Add/Edit button
                    Button {
                        showingModesPicker = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                Capsule()
                                    .fill(.white.opacity(0.1))
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            // Blocking preview
            blockingPreview
        }
    }

    // MARK: - Blocking Preview

    @State private var showingQuickBlockEditor = false

    private var blockingPreview: some View {
        let websites = modeManager.selectedMode?.websiteDomains ?? []
        #if os(iOS)
        let appSelection = modeManager.selectedMode?.appSelection
        let appTokens = Array(appSelection?.applicationTokens ?? [])
        let categoryTokens = Array(appSelection?.categoryTokens ?? [])
        #else
        let appTokens: [Any] = []
        let categoryTokens: [Any] = []
        #endif

        return Group {
            #if os(iOS)
            BlockingPreviewView(
                websites: websites,
                appTokens: appTokens,
                categoryTokens: categoryTokens,
                onTapApps: { showingQuickBlockEditor = true },
                onTapSites: { showingQuickBlockEditor = true },
                animateTrigger: modeManager.selectedModeId
            )
            #else
            BlockingPreviewView(
                websites: websites,
                onTapSites: { showingQuickBlockEditor = true }
            )
            #endif
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .sheet(isPresented: $showingQuickBlockEditor) {
            if let mode = modeManager.selectedMode {
                QuickBlockEditorView(mode: mode) { updatedMode in
                    modeManager.updateMode(updatedMode)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var isTimerActive: Bool {
        localTimerActive || (timerSyncManager.timerState?.isActive ?? false)
    }

    /// Current mode's accent color - animates when mode changes
    /// Uses schedule color when in schedule view mode
    private var modeColor: Color {
        // If in schedule mode, use schedule colors
        if viewMode == .schedule {
            return scheduleAccentColor
        }

        // Otherwise use timer mode color
        guard let mode = modeManager.selectedMode else {
            return DesignSystem.Colors.accent
        }
        return mode.primaryColor
    }

    /// Schedule accent color based on active or next upcoming schedule
    private var scheduleAccentColor: Color {
        // Active schedule takes priority
        if let active = scheduleManager.activeSchedule {
            return active.primaryColor
        }
        // Next enabled schedule
        if let next = findNextSchedule() {
            return next.primaryColor
        }
        // First enabled schedule
        if let firstEnabled = scheduleManager.schedules.first(where: { $0.isEnabled }) {
            return firstEnabled.primaryColor
        }
        // Default
        return DesignSystem.Colors.accent
    }

    /// Subtle ambient gradient that reflects the selected mode
    private var ambientModeGradient: some View {
        GeometryReader { geometry in
            ZStack {
                // Top ambient glow
                RadialGradient(
                    colors: [
                        modeColor.opacity(0.12),
                        modeColor.opacity(0.05),
                        .clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: geometry.size.height * 0.6
                )

                // Subtle bottom accent
                RadialGradient(
                    colors: [
                        modeColor.opacity(0.06),
                        .clear
                    ],
                    center: .bottom,
                    startRadius: 0,
                    endRadius: geometry.size.height * 0.4
                )
            }
        }
    }

    private var currentProgress: Double {
        if localTimerActive, let end = localTimerEnd {
            let total = selectedDuration
            let remaining = max(0, end.timeIntervalSinceNow)
            return total > 0 ? 1.0 - (remaining / total) : 0
        }
        return timerSyncManager.timerState?.progress ?? 0
    }

    private var currentRemainingTime: TimeInterval {
        if localTimerActive {
            return localTimerRemaining
        }
        return timerSyncManager.displayRemainingTime
    }

    /// How long the user has been focusing in the current session
    private var sessionFocusedTime: TimeInterval {
        if localTimerActive, let start = localTimerStart {
            return Date().timeIntervalSince(start)
        }
        return sessionPlannedDuration - currentRemainingTime
    }

    /// Check if emergency exit is available for strict mode session
    private var emergencyExitStatus: EmergencyExitStatus {
        guard sessionIsStrict, let start = localTimerStart else {
            return .notAvailable(reason: .fullyLocked)
        }
        return hardModeManager.checkEmergencyExitAvailability(
            sessionStartTime: start,
            isPremiumUser: premiumManager.isPremium
        )
    }

    private var remainingTimeString: String {
        let totalSeconds = isTimerActive
            ? Int(currentRemainingTime)
            : Int(selectedDuration)

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        let ringSize: CGFloat = 260
        let strokeWidth: CGFloat = 4

        return ZStack {
            // Soft ambient glow when active
            if isTimerActive {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                modeColor.opacity(0.15),
                                modeColor.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: ringSize * 0.4,
                            endRadius: ringSize * 0.7
                        )
                    )
                    .frame(width: ringSize + 60, height: ringSize + 60)
            }

            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: strokeWidth)
                .frame(width: ringSize, height: ringSize)

            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: isTimerActive ? currentProgress : 1.0)
                .stroke(
                    AngularGradient(
                        colors: [
                            modeColor,
                            modeColor.opacity(0.7),
                            modeColor
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .shadow(color: modeColor.opacity(0.4), radius: 8, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.5), value: currentProgress)

            // Time and status
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Mode name (when active)
                if isTimerActive, let mode = modeManager.selectedMode {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(mode.name)
                            .font(DesignSystem.Typography.captionMedium)
                    }
                    .foregroundStyle(modeColor)
                    .padding(.bottom, DesignSystem.Spacing.xs)
                }

                // Time display
                if isTimerActive {
                    Text(remainingTimeString)
                        .font(.system(size: 56, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } else {
                    Button {
                        showingDurationPicker = true
                    } label: {
                        Text(remainingTimeString)
                            .font(.system(size: 56, weight: .light, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    .buttonStyle(.plain)
                }

                // Status
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isTimerActive ? modeColor : Color.white.opacity(0.4))
                    .textCase(.uppercase)
                    .tracking(3)
            }
        }
    }

    private var statusText: String {
        if isTimerActive {
            return sessionIsStrict ? "locked" : "focusing"
        }
        return "ready"
    }

    // MARK: - Duration Selector

    private var durationSelector: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach([15, 25, 45, 60], id: \.self) { minutes in
                durationPill(minutes: minutes)
            }

            // Custom duration button
            Button {
                showingDurationPicker = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .buttonStyle(PillButtonStyle(isSelected: false))
        }
    }

    private func durationPill(minutes: Int) -> some View {
        let isSelected = selectedDuration == TimeInterval(minutes * 60)

        return Button {
            withAnimation(DesignSystem.Animation.quick) {
                selectedDuration = TimeInterval(minutes * 60)
            }
        } label: {
            Text(minutes < 60 ? "\(minutes)m" : "\(minutes/60)h")
        }
        .buttonStyle(PillButtonStyle(isSelected: isSelected))
    }

    // MARK: - Strict Mode Toggle

    private var strictModeToggle: some View {
        Button {
            if premiumManager.isPremium {
                withAnimation(DesignSystem.Animation.quick) {
                    premiumManager.toggleStrictMode()
                }
            } else {
                showingPaywall = true
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: premiumManager.isStrictModeEnabled ? "lock.fill" : "lock.open")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(premiumManager.isStrictModeEnabled
                                     ? DesignSystem.Colors.accent
                                     : DesignSystem.Colors.textMuted)

                Text("Strict Mode")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(premiumManager.isStrictModeEnabled
                                     ? DesignSystem.Colors.textPrimary
                                     : DesignSystem.Colors.textSecondary)

                if !premiumManager.isPremium {
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(DesignSystem.Colors.accent)
                        }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background {
                Capsule()
                    .fill(premiumManager.isStrictModeEnabled
                          ? DesignSystem.Colors.accentSoft
                          : DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        premiumManager.isStrictModeEnabled
                            ? DesignSystem.Colors.accent.opacity(0.5)
                            : DesignSystem.Colors.border,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Strict Mode Active Indicator

    private var strictModeActiveIndicator: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.caution)

            Text("Session locked")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.caution)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background {
            Capsule()
                .fill(DesignSystem.Colors.caution.opacity(0.12))
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            if isTimerActive {
                if sessionIsStrict {
                    // STRICT MODE: Session is locked
                    strictModeActionButton
                } else {
                    // Normal session: End button available
                    Button {
                        showingEndDelay = true
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("End Session")
                        }
                    }
                    .buttonStyle(FrostedButtonStyle(isProminent: false))
                    .disabled(isLoading)
                }
            } else {
                // Start focus - prominent frosted white button
                if isLoading {
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 28)
                                .fill(.white.opacity(0.95))
                        }
                } else {
                    FrostedStartButton(
                        title: "Start Focus",
                        accentColor: modeColor,
                        isLocked: premiumManager.isStrictModeEnabled
                    ) {
                        startFocusSession()
                    }
                    .animation(.easeInOut(duration: 0.3), value: modeColor)
                }
            }
        }
    }

    /// Strict mode action button - locked by default, emergency exit after commitment
    private var strictModeActionButton: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            switch emergencyExitStatus {
            case .available(let focusedMinutes, _):
                // Commitment met - show emergency exit option (subtle, not prominent)
                Button {
                    showingHardModeDelay = true
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "escape")
                            .font(.system(size: 12))
                        Text("Emergency Exit")
                            .font(DesignSystem.Typography.captionMedium)
                    }
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                }
                .buttonStyle(.plain)

                Text("You've focused for \(focusedMinutes) min")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)

            case .notAvailable(let reason):
                // Show why exit is not available (or nothing at all)
                switch reason {
                case .notEnoughCommitment(let remaining):
                    // Show subtle countdown to when exit becomes available
                    let minutes = Int(remaining / 60) + 1
                    Text("Session locked for \(minutes) more min")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)

                case .requiresPro:
                    // PRO users only get escape hatch - free users are fully locked
                    Text("Session locked")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)

                case .fullyLocked:
                    // No escape possible
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                        Text("Session locked until completion")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundStyle(DesignSystem.Colors.textMuted)

                }
            }
        }
    }

    // MARK: - Actions

    private func startFocusSession() {
        // If strict mode is enabled, show confirmation first
        if premiumManager.isStrictModeEnabled {
            showingStrictConfirmation = true
            return
        }

        performStartSession(isStrict: false)
    }

    private func confirmStartStrict() {
        performStartSession(isStrict: true)
    }

    private func performStartSession(isStrict: Bool) {
        isLoading = true
        sessionIsStrict = isStrict

        // Try synced timer first, fall back to local
        if supabaseManager.isAuthenticated {
            Task {
                do {
                    try await timerSyncManager.startTimer(duration: selectedDuration)
                    isLoading = false
                } catch {
                    print("Sync failed, using local timer: \(error)")
                    startLocalTimer()
                    isLoading = false
                }
            }
        } else {
            startLocalTimer()
            isLoading = false
        }
    }

    private func stopFocusSession() {
        // This should only be called for non-strict sessions
        // Strict sessions use the emergency exit flow
        if sessionIsStrict {
            // For strict mode, emergency exit is handled by strictModeActionButton
            return
        }

        // Normal session - show the end delay confirmation
        showingEndDelay = true
    }

    private func performStopSession() {
        isLoading = true

        if localTimerActive {
            stopLocalTimer()
            isLoading = false
        } else {
            Task {
                do {
                    try await timerSyncManager.stopTimer()
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
                isLoading = false
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        } else {
            return "\(minutes) minutes"
        }
    }

    // MARK: - Local Timer (Fallback)

    private func startLocalTimer() {
        let sessionId = UUID()

        localTimerActive = true
        localTimerStart = Date()
        localTimerEnd = Date().addingTimeInterval(selectedDuration)
        localTimerRemaining = selectedDuration
        sessionPlannedDuration = selectedDuration

        // Start enforcement
        blockEnforcementManager.startEnforcement()

        // Notify Deep Work Companion
        companionManager.onSessionStart(sessionId: sessionId)

        // Start countdown
        localTimerTask = Task { @MainActor in
            while !Task.isCancelled && localTimerActive {
                if let end = localTimerEnd {
                    localTimerRemaining = max(0, end.timeIntervalSinceNow)

                    // Update progress for haptic milestones
                    let progress = 1.0 - (localTimerRemaining / sessionPlannedDuration)
                    companionManager.onProgressUpdate(progress: progress)

                    if localTimerRemaining <= 0 {
                        stopLocalTimer(completed: true)
                        break
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }

    private func stopLocalTimer(completed: Bool = false) {
        let sessionId = companionManager.currentSessionId ?? UUID()

        // Record session to stats
        if let startTime = localTimerStart {
            let actualDuration = Int(Date().timeIntervalSince(startTime))
            let blockedDomains = websiteSyncManager.blockedWebsites.map { $0.domain }
            let session = FocusSession(
                userId: supabaseManager.currentUserId ?? UUID(),
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                startTime: startTime,
                endTime: Date(),
                plannedDurationSeconds: Int(sessionPlannedDuration),
                actualDurationSeconds: actualDuration,
                wasCompleted: completed,
                blockedWebsiteCount: websiteSyncManager.blockedWebsites.count,
                blockedAppCount: blockEnforcementManager.localAppSelection.appCount,
                blockedWebsites: blockedDomains,
                modeName: modeManager.selectedMode?.name
            )
            statsManager.recordSession(session)
        }

        // Notify Deep Work Companion - may trigger review prompt
        companionManager.onSessionEnd(sessionId: sessionId, completed: completed)

        localTimerActive = false
        localTimerStart = nil
        localTimerEnd = nil
        localTimerRemaining = 0
        localTimerTask?.cancel()
        localTimerTask = nil
        sessionIsStrict = false
        sessionPlannedDuration = 0

        // Stop enforcement
        blockEnforcementManager.stopEnforcement()

        // Trigger post-session protection if enabled
        regretManager.startPostSessionProtection()

        // Show session review if companion manager wants to
        if companionManager.shouldShowReviewPrompt {
            showingSessionReview = true
        }
    }

    // MARK: - Status Pills

    private var statusPills: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            statusPill(
                icon: "globe",
                count: websiteSyncManager.blockedWebsites.count,
                label: "sites"
            )

            #if os(iOS)
            statusPill(
                icon: "app.badge",
                count: blockEnforcementManager.localAppSelection.appCount,
                label: "apps"
            )
            #endif
        }
    }

    private func statusPill(icon: String, count: Int, label: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.accent)

            Text("\(count)")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background {
            Capsule()
                .fill(DesignSystem.Colors.backgroundCard)
        }
    }
}

// MARK: - Quick Block Editor

#if os(iOS)
struct QuickBlockEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let mode: FocusMode
    let onSave: (FocusMode) -> Void

    @State private var editedMode: FocusMode
    @State private var showingAppPicker = false
    @State private var newWebsite = ""

    private var appTokens: [ApplicationToken] {
        Array(editedMode.appSelection?.applicationTokens ?? [])
    }

    private var categoryTokens: [ActivityCategoryToken] {
        Array(editedMode.appSelection?.categoryTokens ?? [])
    }

    private var totalApps: Int {
        appTokens.count + categoryTokens.count
    }

    private var modeColor: Color {
        Color(hex: mode.color)
    }

    init(mode: FocusMode, onSave: @escaping (FocusMode) -> Void) {
        self.mode = mode
        self.onSave = onSave
        self._editedMode = State(initialValue: mode)
    }

    var body: some View {
        NavigationStack {
            List {
                // Apps Section
                Section {
                    // Show blocked app icons
                    if !appTokens.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(Array(appTokens.enumerated()), id: \.offset) { _, token in
                                    Label(token)
                                        .labelStyle(.iconOnly)
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .padding(.vertical, DesignSystem.Spacing.xs)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }

                    Button {
                        showingAppPicker = true
                    } label: {
                        HStack {
                            Image(systemName: totalApps > 0 ? "pencil" : "plus.circle.fill")
                                .foregroundStyle(modeColor)
                            Text(totalApps > 0 ? "Edit App Selection" : "Select Apps to Block")
                            Spacer()
                            if totalApps > 0 {
                                Text("\(totalApps) selected")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                } header: {
                    Text("Apps (\(totalApps))")
                }

                // Websites Section
                Section {
                    ForEach(editedMode.websiteDomains, id: \.self) { domain in
                        HStack {
                            WebsiteFavicon(domain: domain, size: 28)
                            Text(domain)
                                .font(DesignSystem.Typography.body)
                        }
                    }
                    .onDelete { indexSet in
                        var domains = editedMode.websiteDomains
                        domains.remove(atOffsets: indexSet)
                        editedMode.websiteDomains = domains
                    }

                    HStack {
                        TextField("Add website (e.g. twitter.com)", text: $newWebsite)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit {
                                addWebsite()
                            }

                        Button {
                            addWebsite()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(modeColor)
                        }
                        .disabled(newWebsite.isEmpty)
                    }
                } header: {
                    Text("Websites (\(editedMode.websiteDomains.count))")
                }
            }
            .navigationTitle("Edit \(mode.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editedMode)
                        dismiss()
                    }
                }
            }
            .familyActivityPicker(isPresented: $showingAppPicker, selection: Binding(
                get: { editedMode.appSelection ?? FamilyActivitySelection() },
                set: { editedMode.setAppSelection($0) }
            ))
            .tint(modeColor)
        }
        .presentationDetents([.medium, .large])
    }

    private func addWebsite() {
        let domain = newWebsite.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")

        if !domain.isEmpty && !editedMode.websiteDomains.contains(domain) {
            editedMode.websiteDomains.append(domain)
            newWebsite = ""
        }
    }
}
#endif

// MARK: - Blocking Preview View (Single Line, Tappable)

#if os(iOS)
struct BlockingPreviewView: View {
    let websites: [String]
    let appTokens: [ApplicationToken]
    let categoryTokens: [ActivityCategoryToken]
    var onTapApps: (() -> Void)? = nil
    var onTapSites: (() -> Void)? = nil
    var animateTrigger: UUID? = nil

    @State private var visibleCount: Int = 0
    @State private var iconScale: CGFloat = 1.0

    private var totalApps: Int {
        appTokens.count + categoryTokens.count
    }

    private var extraApps: Int {
        max(0, totalApps - 3)
    }

    private var extraSites: Int {
        max(0, websites.count - 3)
    }

    private let iconSize: CGFloat = 28
    private let iconSpacing: CGFloat = -8

    var body: some View {
        // Fixed height container to prevent layout shifts
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Apps section (always present, just different content)
            Button {
                onTapApps?()
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    if totalApps > 0 {
                        // Stacked app icons with +X indicator
                        HStack(spacing: iconSpacing) {
                            if !appTokens.isEmpty {
                                ForEach(Array(appTokens.prefix(3).enumerated()), id: \.offset) { index, token in
                                    Label(token)
                                        .labelStyle(.iconOnly)
                                        .scaleEffect(0.55)
                                        .frame(width: iconSize, height: iconSize)
                                        .clipShape(Circle())
                                        .scaleEffect(index < visibleCount ? iconScale : 0.8)
                                        .opacity(index < visibleCount ? 1 : 0.5)
                                }
                            } else {
                                // Generic icon when only categories selected
                                Image(systemName: "app.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DesignSystem.Colors.accent)
                                    .frame(width: iconSize, height: iconSize)
                                    .background {
                                        Circle()
                                            .fill(DesignSystem.Colors.accentSoft)
                                    }
                                    .scaleEffect(iconScale)
                            }

                            // +X indicator if more than 3
                            if extraApps > 0 {
                                Text("+\(extraApps)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .frame(width: iconSize, height: iconSize)
                                    .background {
                                        Circle()
                                            .fill(DesignSystem.Colors.backgroundCard)
                                    }
                                    .opacity(visibleCount >= 3 ? 1 : 0)
                            }
                        }

                        (Text("\(totalApps)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        + Text(" apps")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textSecondary))
                            .fixedSize()
                    } else {
                        // Empty apps placeholder
                        Image(systemName: "app.badge.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .frame(width: iconSize, height: iconSize)

                        Text("No apps")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .fixedSize()
                    }
                }
            }
            .buttonStyle(.plain)

            // Sites section (always present, just different content)
            Button {
                onTapSites?()
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if !websites.isEmpty {
                        // Stacked favicons with +X indicator
                        HStack(spacing: iconSpacing) {
                            ForEach(Array(websites.prefix(3).enumerated()), id: \.element) { index, domain in
                                WebsiteFavicon(domain: domain, size: iconSize, style: .compact)
                                    .scaleEffect(index < visibleCount ? iconScale : 0.8)
                                    .opacity(index < visibleCount ? 1 : 0.5)
                            }

                            // +X indicator if more than 3
                            if extraSites > 0 {
                                Text("+\(extraSites)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .frame(width: iconSize, height: iconSize)
                                    .background {
                                        Circle()
                                            .fill(DesignSystem.Colors.backgroundCard)
                                    }
                                    .opacity(visibleCount >= 3 ? 1 : 0)
                            }
                        }

                        (Text("\(websites.count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        + Text(" sites")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textSecondary))
                            .fixedSize()
                    } else {
                        // Empty sites placeholder
                        Image(systemName: "globe")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .frame(width: iconSize, height: iconSize)

                        Text("No sites")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .fixedSize()
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 36)
        .onAppear {
            runRevealAnimation()
        }
        .onChange(of: animateTrigger) { _, _ in
            runRevealAnimation()
        }
    }

    private func runRevealAnimation() {
        // Reset
        visibleCount = 0
        iconScale = 0.9

        let maxIcons = max(min(3, appTokens.count), min(3, websites.count), 1)

        // Smooth fade-in with slight stagger
        for i in 0...maxIcons {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                withAnimation(.easeOut(duration: 0.25)) {
                    visibleCount = i + 1
                    iconScale = 1.0
                }
            }
        }
    }
}
#else
struct BlockingPreviewView: View {
    let websites: [String]
    var onTapSites: (() -> Void)? = nil

    private var extraSites: Int {
        max(0, websites.count - 3)
    }

    private let iconSize: CGFloat = 28

    var body: some View {
        Button {
            onTapSites?()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if !websites.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(Array(websites.prefix(3).enumerated()), id: \.element) { _, domain in
                            WebsiteFavicon(domain: domain, size: iconSize, style: .compact)
                        }

                        if extraSites > 0 {
                            Text("+\(extraSites)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .frame(width: iconSize, height: iconSize)
                                .background {
                                    Circle()
                                        .fill(DesignSystem.Colors.backgroundCard)
                                }
                        }
                    }

                    (Text("\(websites.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    + Text(" sites")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary))
                        .fixedSize()
                } else {
                    // Empty sites placeholder for consistent layout
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(width: iconSize, height: iconSize)

                    Text("No sites")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .fixedSize()
                }
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 36)
    }
}
#endif

// MARK: - Mode Chip

struct ModeChip: View {
    let mode: FocusMode
    let isSelected: Bool
    let onTap: () -> Void

    private var modeColor: Color {
        Color(hex: mode.color)
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: mode.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? .white : modeColor)

                Text(mode.name)
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textPrimary)

                if mode.isStrictMode {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : DesignSystem.Colors.accent)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background {
                Capsule()
                    .fill(isSelected ? modeColor : DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Schedule Pill

struct SchedulePill: View {
    let schedule: FocusSchedule
    let isSelected: Bool
    let isActive: Bool
    let onTap: () -> Void
    let onEdit: () -> Void

    private var scheduleColor: Color {
        schedule.primaryColor
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                // Active indicator
                if isActive {
                    Circle()
                        .fill(DesignSystem.Colors.success)
                        .frame(width: 6, height: 6)
                }

                Text(schedule.name)
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textPrimary)

                if schedule.isStrictMode {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : scheduleColor)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background {
                Capsule()
                    .fill(isSelected ? scheduleColor : DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : scheduleColor.opacity(0.4), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }
}

#Preview {
    @Previewable @State var viewMode = "Timer"
    FocusSessionView(viewModeBinding: $viewMode)
        .environmentObject(SupabaseManager.shared)
        .environmentObject(TimerSyncManager.shared)
        .environmentObject(WebsiteSyncManager.shared)
        .environmentObject(BlockEnforcementManager.shared)
}
