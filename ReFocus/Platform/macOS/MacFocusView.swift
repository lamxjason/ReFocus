import SwiftUI

#if os(macOS)
struct MacFocusView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var timerSyncManager: TimerSyncManager
    @EnvironmentObject var websiteSyncManager: WebsiteSyncManager
    @EnvironmentObject var blockEnforcementManager: BlockEnforcementManager
    @ObservedObject private var premiumManager = PremiumManager.shared
    @ObservedObject private var modeManager = FocusModeManager.shared
    @ObservedObject private var sessionSyncManager = FocusSessionSyncManager.shared
    @StateObject private var scheduleManager = ScheduleManager.shared
    @StateObject private var rewardManager = RewardManager.shared
    @StateObject private var localPreferences = LocalPreferencesManager.shared
    @StateObject private var hardModeManager = HardModeManager.shared
    private let statsManager = StatsManager.shared

    // View mode binding to sync with parent
    @Binding var viewModeString: String
    private var viewMode: ViewMode {
        ViewMode(rawValue: viewModeString) ?? .timer
    }

    init(viewModeBinding: Binding<String>) {
        self._viewModeString = viewModeBinding
    }

    @State private var selectedDuration: TimeInterval = 25 * 60
    @State private var showingPaywall = false
    @State private var showingModesPicker = false
    @State private var showingScheduleList = false
    @State private var showingEndScheduleConfirmation = false
    @State private var showingEndScheduleDelay = false
    @State private var isLoading = false
    @State private var showingStrictConfirmation = false

    enum ViewMode: String, CaseIterable {
        case timer = "Timer"
        case schedule = "Schedule"
    }

    // Local timer
    @State private var localTimerActive = false
    @State private var localTimerStart: Date?
    @State private var localTimerEnd: Date?
    @State private var localTimerRemaining: TimeInterval = 0
    @State private var localTimerTask: Task<Void, Never>?
    @State private var sessionIsStrict = false
    @State private var sessionPlannedDuration: TimeInterval = 0

    // Schedule selection
    @State private var selectedScheduleId: UUID?

    // Reward popup
    @State private var showingRewardPopup = false
    @State private var earnedReward: RewardManager.SessionReward?

    // Achievement popup
    @State private var showingAchievementPopup = false
    @State private var unlockedAchievement: Achievement?

    // Level up celebration
    @State private var showingLevelUp = false
    @State private var newLevel: Int = 0

    // Session review
    @State private var showingSessionReview = false

    // Emergency exit for strict mode
    @State private var showingEmergencyExit = false
    @State private var currentSessionId = UUID()

    var body: some View {
        ZStack {
            // Background
            DesignSystem.Colors.background
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Ambient gradient
            ambientModeGradient
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.5), value: modeColor)

            VStack(spacing: 0) {
                // View mode toggle (Timer vs Schedule)
                if !isTimerActive && !scheduleManager.isScheduleActive && !scheduleManager.isOnBreak {
                    viewModeToggle
                        .padding(.top, DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.md)

                    // Streak warning when at risk (only show if user wants streak warnings)
                    if statsManager.isStreakAtRisk && localPreferences.showStreakWarnings {
                        StreakWarningBanner(
                            currentStreak: statsManager.currentStreak,
                            hoursRemaining: statsManager.hoursRemainingToProtectStreak,
                            freezesAvailable: statsManager.streakFreezesAvailable,
                            onUseFreeze: {
                                if statsManager.useStreakFreeze() {
                                    // Streak freeze used successfully
                                }
                            }
                        )
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.bottom, DesignSystem.Spacing.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                Spacer()

                // Shared ring area
                timerRingArea

                Spacer()
                    .frame(height: DesignSystem.Spacing.lg)

                // Mode-specific content below ring
                Group {
                    // Break mode always shows schedule content (with break controls)
                    if scheduleManager.isOnBreak {
                        scheduleBelowRingContent
                    } else if viewMode == .timer {
                        timerBelowRingContent
                    } else {
                        scheduleBelowRingContent
                    }
                }
                .frame(minHeight: 180)
                .animation(.easeInOut(duration: 0.2), value: viewMode)
                .animation(.easeInOut(duration: 0.2), value: scheduleManager.isOnBreak)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(modeColor)
        .animation(.easeInOut(duration: 0.3), value: modeColor)
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .sheet(isPresented: $showingScheduleList) {
            ScheduleListView()
                .frame(minWidth: 500, minHeight: 600)
        }
        .sheet(isPresented: $showingModesPicker) {
            NavigationStack {
                FocusModesView()
            }
            .frame(minWidth: 500, minHeight: 600)
        }
        .confirmationDialog(
            "Start with Session Lock?",
            isPresented: $showingStrictConfirmation,
            titleVisibility: .visible
        ) {
            Button("Lock Session") {
                performStartSession(isStrict: true)
            }
            Button("Start Without Lock") {
                performStartSession(isStrict: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Session Lock prevents ending the session early. You won't be able to stop until the timer completes.")
        }
        .confirmationDialog(
            "End Schedule Early?",
            isPresented: $showingEndScheduleConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Now", role: .destructive) {
                scheduleManager.endScheduleEarly()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will unblock all apps and websites until the next scheduled time.")
        }
        .sheet(isPresented: $showingEndScheduleDelay) {
            EndSessionDelayView(
                onConfirm: {
                    showingEndScheduleDelay = false
                    scheduleManager.endScheduleEarly()
                },
                onCancel: {
                    showingEndScheduleDelay = false
                },
                modeColor: scheduleAccentColor
            )
            .frame(minWidth: 400, minHeight: 500)
        }
        .sheet(item: Binding(
            get: { scheduleManager.endedSchedule },
            set: { _ in scheduleManager.clearEndedSchedule() }
        )) { endedSchedule in
            ScheduleEndedView(
                schedule: endedSchedule,
                onResume: {
                    scheduleManager.resumeSchedule()
                },
                onTakeBreak: { duration in
                    // Start break mode - schedule will auto-resume when break ends
                    scheduleManager.startBreak(duration: duration, for: endedSchedule)
                    scheduleManager.clearEndedSchedule()
                },
                onDismiss: {
                    scheduleManager.clearEndedSchedule()
                }
            )
            .frame(minWidth: 450, minHeight: 400)
        }
        .sheet(isPresented: $showingRewardPopup) {
            if let reward = earnedReward {
                RewardPopupView(reward: reward) {
                    rewardManager.claimReward(reward)
                    showingRewardPopup = false
                    earnedReward = nil
                    // Check for level up and achievements after reward
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        checkForCelebrations()
                    }
                }
                .frame(minWidth: 400, minHeight: 500)
            }
        }
        .sheet(isPresented: $showingAchievementPopup) {
            if let achievement = unlockedAchievement {
                AchievementPopupView(achievement: achievement) {
                    showingAchievementPopup = false
                    unlockedAchievement = nil
                    // Check for more celebrations
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        checkForCelebrations()
                    }
                }
                .frame(minWidth: 400, minHeight: 500)
            }
        }
        .sheet(isPresented: $showingLevelUp) {
            LevelUpCelebrationView(newLevel: newLevel) {
                showingLevelUp = false
                // Check for achievements after level up
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    checkForNewAchievements()
                }
            }
            .frame(minWidth: 400, minHeight: 600)
        }
        .sheet(isPresented: $showingSessionReview) {
            SessionReviewView(modeColor: modeColor)
                .frame(minWidth: 400, minHeight: 500)
        }
        .sheet(isPresented: $showingEmergencyExit) {
            EmergencyExitView(
                sessionId: currentSessionId,
                focusedTime: focusedTimeForEmergencyExit,
                remainingTime: localTimerRemaining,
                onConfirmExit: {
                    showingEmergencyExit = false
                    stopLocalTimer()
                },
                onCancel: {
                    showingEmergencyExit = false
                },
                modeColor: modeColor
            )
            .frame(minWidth: 400, minHeight: 500)
        }
    }

    // Computed property for emergency exit focused time
    private var focusedTimeForEmergencyExit: TimeInterval {
        guard let start = localTimerStart else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // Emergency exit availability status
    private var emergencyExitStatus: EmergencyExitStatus {
        guard sessionIsStrict, let startTime = localTimerStart else {
            return .notAvailable(reason: .requiresPro)
        }
        return hardModeManager.checkEmergencyExitAvailability(
            sessionStartTime: startTime,
            isPremiumUser: premiumManager.isPremium
        )
    }

    // MARK: - Achievement & Level Up Checking

    private func checkForCelebrations() {
        // Priority: Level Up > Achievements
        guard !showingRewardPopup && !showingAchievementPopup && !showingLevelUp else { return }

        // Check for level up first
        if let level = statsManager.popPendingLevelUp() {
            newLevel = level
            showingLevelUp = true
            return
        }

        // Then check for achievements
        checkForNewAchievements()
    }

    private func checkForNewAchievements() {
        guard !showingRewardPopup && !showingAchievementPopup && !showingLevelUp else { return }
        if let achievement = statsManager.popNextUnlockedAchievement() {
            unlockedAchievement = achievement
            showingAchievementPopup = true
        }
    }

    // MARK: - Computed Properties

    private var isTimerActive: Bool {
        localTimerActive || (timerSyncManager.timerState?.isActive ?? false)
    }

    private var modeColor: Color {
        if scheduleManager.isOnBreak {
            return DesignSystem.Colors.caution
        }
        if viewMode == .schedule {
            return scheduleAccentColor
        }
        return modeManager.selectedMode?.primaryColor ?? DesignSystem.Colors.accent
    }

    private var scheduleAccentColor: Color {
        if let active = scheduleManager.activeSchedule {
            return active.primaryColor
        }
        if let upcoming = scheduleManager.findNextEnabledSchedule() {
            return upcoming.primaryColor
        }
        if let firstEnabled = scheduleManager.schedules.first(where: { $0.isEnabled }) {
            return firstEnabled.primaryColor
        }
        return DesignSystem.Colors.accent
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

    // MARK: - Ambient Gradient

    private var ambientModeGradient: some View {
        GeometryReader { geometry in
            ZStack {
                RadialGradient(
                    colors: [
                        modeColor.opacity(0.15),
                        modeColor.opacity(0.05),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.2),
                    startRadius: 0,
                    endRadius: geometry.size.height * 0.5
                )
            }
        }
    }

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        GeometryReader { geometry in
            let segmentWidth = (geometry.size.width - 8) / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DesignSystem.Colors.backgroundCard)

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
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewMode)

                HStack(spacing: 0) {
                    ForEach(ViewMode.allCases, id: \.rawValue) { mode in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModeString = mode.rawValue
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: mode == .timer ? "timer" : "calendar.badge.clock")
                                    .font(.system(size: 14, weight: .medium))

                                Text(mode.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
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
        .frame(width: 260, height: 44)
    }

    // MARK: - Timer Ring Area

    private var timerRingArea: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.Colors.backgroundCard, lineWidth: 8)
                .frame(width: 240, height: 240)

            // Break mode always shows schedule content (with break state)
            if scheduleManager.isOnBreak {
                scheduleRingContent
            } else if viewMode == .timer {
                timerRingContent
            } else {
                scheduleRingContent
            }
        }
        .frame(width: 240, height: 240)
        .animation(.easeInOut(duration: 0.2), value: viewMode)
        .animation(.easeInOut(duration: 0.2), value: scheduleManager.isOnBreak)
    }

    private var timerRingContent: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: isTimerActive ? currentProgress : 1.0)
                .stroke(modeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text(remainingTimeString)
                    .font(.system(size: 56, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .contentTransition(.numericText())

                HStack(spacing: 4) {
                    if sessionIsStrict && isTimerActive {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(modeColor)
                    }

                    Text(isTimerActive ? (sessionIsStrict ? "locked" : "focusing") : "ready")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(2)
                }
            }
        }
    }

    private var scheduleRingContent: some View {
        ZStack {
            // Break mode takes priority
            if scheduleManager.isOnBreak, let breakSchedule = scheduleManager.breakSchedule {
                let breakProgress = scheduleManager.breakDuration > 0
                    ? 1.0 - (scheduleManager.breakRemainingTime / scheduleManager.breakDuration)
                    : 0

                Circle()
                    .trim(from: 0, to: breakProgress)
                    .stroke(
                        DesignSystem.Colors.caution,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 8) {
                    Text(formatScheduleRemaining(scheduleManager.breakRemainingTime))
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .contentTransition(.numericText())

                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DesignSystem.Colors.caution)

                            Text("on break")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.caution)
                                .textCase(.uppercase)
                                .tracking(1)
                        }

                        Text("from \(breakSchedule.name)")
                            .font(.system(size: 10))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
            } else if scheduleManager.isScheduleSkipped, let skipped = scheduleManager.skippedSchedule {
                // Schedule is paused/skipped
                VStack(spacing: 8) {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 56, weight: .thin))
                        .foregroundStyle(skipped.primaryColor.opacity(0.7))

                    VStack(spacing: 4) {
                        Text("paused")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(skipped.primaryColor)
                            .textCase(.uppercase)
                            .tracking(2)

                        Text(skipped.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(skipped.primaryColor)

                        if let remaining = scheduleManager.skipRemainingTime {
                            Text("Resumes in \(formatScheduleRemaining(remaining))")
                                .font(.system(size: 11))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }
                    }
                }
            } else if let activeSchedule = scheduleManager.activeSchedule {
                Circle()
                    .trim(from: 0, to: scheduleProgress)
                    .stroke(activeSchedule.primaryColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(formatScheduleRemaining(scheduleManager.liveRemainingTime))
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(DesignSystem.Colors.success)
                            .frame(width: 8, height: 8)

                        if activeSchedule.isStrictMode {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(activeSchedule.primaryColor)
                        }

                        Text("active now")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.success)
                            .textCase(.uppercase)
                            .tracking(1)
                    }
                }
            } else if let nextSchedule = scheduleManager.findNextEnabledSchedule(),
                      let timeUntil = scheduleManager.timeUntilNextSchedule {
                VStack(spacing: 8) {
                    Text(formatTimeUntilSchedule(timeUntil))
                        .font(.system(size: 36, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    VStack(spacing: 2) {
                        Text("until")
                            .font(.system(size: 11))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .textCase(.uppercase)

                        Text(nextSchedule.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(nextSchedule.primaryColor)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)

                    Text("free time")
                        .font(.system(size: 11, weight: .medium))
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
        }
    }

    // MARK: - Schedule Below Ring Content

    private var scheduleBelowRingContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            if scheduleManager.isOnBreak {
                // Break mode content
                breakBelowRingContent
            } else {
                // Schedule selector pills
                if !scheduleManager.schedules.isEmpty {
                    scheduleSelector
                }

                // Blocking preview
                scheduleBlockingPreview

                // Action buttons
                scheduleActionButtons
            }
        }
    }

    // MARK: - Break Below Ring Content

    private var breakBelowRingContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Info text
            if let breakSchedule = scheduleManager.breakSchedule {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Apps & websites unblocked")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("Schedule will auto-resume when break ends")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                // Action buttons
                VStack(spacing: DesignSystem.Spacing.md) {
                    // End Break Early (resume schedule)
                    Text("End Break & Resume")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 200)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background {
                            Capsule()
                                .fill(breakSchedule.gradient)
                        }
                        .contentShape(Capsule())
                        .onTapGesture {
                            scheduleManager.endBreak()
                        }

                    // Cancel break (don't resume)
                    Text("Cancel Break")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background {
                            Capsule()
                                .fill(DesignSystem.Colors.backgroundCard)
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                        }
                        .contentShape(Capsule())
                        .onTapGesture {
                            scheduleManager.cancelBreak()
                        }
                }
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Mode pills
            HStack(spacing: 10) {
                ForEach(modeManager.modes) { mode in
                    ModePillMac(
                        mode: mode,
                        isSelected: modeManager.selectedModeId == mode.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            modeManager.selectMode(mode)
                            selectedDuration = mode.duration
                        }
                    }
                }

                // Edit button
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

            // Blocking preview
            blockingPreview
        }
    }

    // MARK: - Blocking Preview

    private var blockingPreview: some View {
        let websites = modeManager.selectedMode?.websiteDomains ?? []
        let blockedApps = MacAppBlocker.shared.blockedApps
        let appCount = blockedApps.count
        let iconSize: CGFloat = 28

        return HStack(spacing: DesignSystem.Spacing.lg) {
            // Apps - show actual app icons
            HStack(spacing: DesignSystem.Spacing.xs) {
                if appCount > 0 {
                    // Stacked app icons (show first 3)
                    HStack(spacing: -8) {
                        ForEach(Array(blockedApps.prefix(3).enumerated()), id: \.element.id) { _, app in
                            if let iconData = app.iconData,
                               let nsImage = NSImage(data: iconData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .frame(width: iconSize, height: iconSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(modeColor)
                                    .frame(width: iconSize, height: iconSize)
                                    .background {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(modeColor.opacity(0.15))
                                    }
                            }
                        }
                        // +X indicator if more than 3
                        if appCount > 3 {
                            Text("+\(appCount - 3)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .frame(width: iconSize, height: iconSize)
                                .background {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(DesignSystem.Colors.backgroundCard)
                                }
                        }
                    }

                    (Text("\(appCount)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    + Text(" app\(appCount == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary))
                } else {
                    Image(systemName: "app.badge")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(width: iconSize, height: iconSize)

                    Text("No apps")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }

            // Sites - show actual favicons
            HStack(spacing: DesignSystem.Spacing.xs) {
                if !websites.isEmpty {
                    // Stacked favicons (show first 3)
                    HStack(spacing: -8) {
                        ForEach(Array(websites.prefix(3).enumerated()), id: \.element) { _, domain in
                            WebsiteFavicon(domain: domain, size: iconSize, style: .compact)
                        }
                        // +X indicator if more than 3
                        if websites.count > 3 {
                            Text("+\(websites.count - 3)")
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
                    + Text(" site\(websites.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary))
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(width: iconSize, height: iconSize)

                    Text("No sites")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
    }

    // MARK: - Schedule Selector

    private var scheduleSelector: some View {
        HStack(spacing: 10) {
            ForEach(scheduleManager.schedules) { schedule in
                SchedulePillMac(
                    schedule: schedule,
                    isSelected: selectedScheduleId == schedule.id || (selectedScheduleId == nil && schedule.id == scheduleManager.activeSchedule?.id),
                    isActive: schedule.id == scheduleManager.activeSchedule?.id
                ) {
                    withAnimation(DesignSystem.Animation.quick) {
                        selectedScheduleId = schedule.id
                    }
                }
            }

            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(.white.opacity(0.1))
                }
                .contentShape(Capsule())
                .onTapGesture {
                    showingScheduleList = true
                }
        }
    }

    private var scheduleBlockingPreview: some View {
        let schedule = selectedSchedule ?? scheduleManager.activeSchedule
        let websites = schedule?.websiteDomains ?? []
        let blockedApps = MacAppBlocker.shared.blockedApps
        let appCount = blockedApps.count
        let iconSize: CGFloat = 28

        return HStack(spacing: DesignSystem.Spacing.lg) {
            // Apps - show actual app icons
            HStack(spacing: DesignSystem.Spacing.xs) {
                if appCount > 0 {
                    // Stacked app icons (show first 3)
                    HStack(spacing: -8) {
                        ForEach(Array(blockedApps.prefix(3).enumerated()), id: \.element.id) { _, app in
                            if let iconData = app.iconData,
                               let nsImage = NSImage(data: iconData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .frame(width: iconSize, height: iconSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(scheduleAccentColor)
                                    .frame(width: iconSize, height: iconSize)
                                    .background {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(scheduleAccentColor.opacity(0.15))
                                    }
                            }
                        }
                        // +X indicator if more than 3
                        if appCount > 3 {
                            Text("+\(appCount - 3)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .frame(width: iconSize, height: iconSize)
                                .background {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(DesignSystem.Colors.backgroundCard)
                                }
                        }
                    }

                    (Text("\(appCount)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    + Text(" app\(appCount == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary))
                } else {
                    Image(systemName: "app.badge")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(width: iconSize, height: iconSize)

                    Text("No apps")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }

            // Sites - show actual favicons
            HStack(spacing: DesignSystem.Spacing.xs) {
                if !websites.isEmpty {
                    // Stacked favicons (show first 3)
                    HStack(spacing: -8) {
                        ForEach(Array(websites.prefix(3).enumerated()), id: \.element) { _, domain in
                            WebsiteFavicon(domain: domain, size: iconSize, style: .compact)
                        }
                        // +X indicator if more than 3
                        if websites.count > 3 {
                            Text("+\(websites.count - 3)")
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
                    + Text(" site\(websites.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textSecondary))
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(width: iconSize, height: iconSize)

                    Text("No sites")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
    }

    private var scheduleActionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Resume Schedule button when schedule is skipped/paused
            if scheduleManager.isScheduleSkipped, let skipped = scheduleManager.skippedSchedule {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // Info about paused schedule with remaining time
                    HStack(spacing: 6) {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(skipped.primaryColor)

                        if let remaining = scheduleManager.skipRemainingTime {
                            Text("\(skipped.name) paused • \(formatScheduleRemaining(remaining)) left")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        } else {
                            Text("\(skipped.name) is paused")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }

                    // Resume button
                    Text("Resume Schedule")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 200)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background {
                            Capsule()
                                .fill(skipped.gradient)
                        }
                        .contentShape(Capsule())
                        .onTapGesture {
                            scheduleManager.resumeSchedule()
                        }
                }
            }
            // End Schedule button when active (and not strict mode)
            else if scheduleManager.isScheduleActive {
                if let activeSchedule = scheduleManager.activeSchedule, !activeSchedule.isStrictMode {
                    Text("End Schedule Early")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 200)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background {
                            Capsule()
                                .fill(Color.red.opacity(0.8))
                        }
                        .contentShape(Capsule())
                        .onTapGesture {
                            showingEndScheduleDelay = true
                        }
                } else if let activeSchedule = scheduleManager.activeSchedule, activeSchedule.isStrictMode {
                    // Strict mode indicator
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                        Text("Locked until \(activeSchedule.endTime.formatted)")
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                }
            }

            // Manage Schedules button - always visible
            Text(scheduleManager.schedules.isEmpty ? "Create Schedule" : "Manage Schedules")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(minWidth: 200)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [scheduleAccentColor, scheduleAccentColor.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .contentShape(Capsule())
                .onTapGesture {
                    showingScheduleList = true
                }
        }
    }

    private var selectedSchedule: FocusSchedule? {
        if let id = selectedScheduleId {
            return scheduleManager.schedules.first { $0.id == id }
        }
        return scheduleManager.activeSchedule ?? scheduleManager.schedules.first
    }

    // MARK: - Strict Mode Indicator

    private var strictModeActiveIndicator: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            switch emergencyExitStatus {
            case .available(let focusedMinutes, _):
                // Show emergency exit option
                Button {
                    showingEmergencyExit = true
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
                switch reason {
                case .notEnoughCommitment(let remaining):
                    let minutes = Int(remaining / 60) + 1
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.caution)

                        Text("Locked for \(minutes) more min")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.caution)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background {
                        Capsule()
                            .fill(DesignSystem.Colors.caution.opacity(0.12))
                    }

                case .requiresPro, .fullyLocked:
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
            }
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            if isTimerActive {
                Button {
                    stopFocusSession()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: sessionIsStrict ? "lock.fill" : "stop.fill")
                            .font(.system(size: 14))
                        Text(sessionIsStrict ? "Locked" : "End Session")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background {
                        Capsule()
                            .fill(sessionIsStrict ? DesignSystem.Colors.textMuted : Color.red.opacity(0.8))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoading || sessionIsStrict)
                .opacity(sessionIsStrict ? 0.6 : 1.0)
            } else {
                Button {
                    startFocusSession()
                } label: {
                    HStack(spacing: 6) {
                        if premiumManager.isStrictModeEnabled {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14))
                        }
                        Text("Start Focus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background {
                        Capsule()
                            .fill(.white.opacity(0.95))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
    }

    // MARK: - Helper Functions

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
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func formatTimeUntilSchedule(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            if remainingHours > 0 {
                return "\(days)d \(remainingHours)h"
            }
            return "\(days)d"
        } else if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes) min"
        }
        return "\(Int(seconds) % 60)s"
    }

    // MARK: - Actions

    private func startFocusSession() {
        let modeHasStrictMode = modeManager.selectedMode?.isStrictMode ?? false
        let globalStrictEnabled = premiumManager.isStrictModeEnabled

        if modeHasStrictMode || globalStrictEnabled {
            if premiumManager.isPremium {
                showingStrictConfirmation = true
            } else {
                showingPaywall = true
            }
            return
        }

        performStartSession(isStrict: false)
    }

    private func performStartSession(isStrict: Bool) {
        isLoading = true
        sessionIsStrict = isStrict
        sessionPlannedDuration = selectedDuration
        currentSessionId = UUID()  // Generate new session ID

        if supabaseManager.isAuthenticated {
            Task {
                do {
                    try await timerSyncManager.startTimer(duration: selectedDuration)
                    isLoading = false
                } catch {
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
        guard !sessionIsStrict else { return }

        isLoading = true

        if localTimerActive {
            stopLocalTimer()
            isLoading = false
        } else {
            Task {
                try? await timerSyncManager.stopTimer()
                isLoading = false
            }
        }
    }

    private func startLocalTimer() {
        localTimerActive = true
        localTimerStart = Date()
        localTimerEnd = Date().addingTimeInterval(selectedDuration)
        localTimerRemaining = selectedDuration

        blockEnforcementManager.startEnforcement()

        localTimerTask = Task { @MainActor in
            while !Task.isCancelled && localTimerActive {
                if let end = localTimerEnd {
                    localTimerRemaining = max(0, end.timeIntervalSinceNow)

                    if localTimerRemaining <= 0 {
                        stopLocalTimer()
                        break
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    private func stopLocalTimer() {
        let actualDuration: TimeInterval
        if let start = localTimerStart {
            actualDuration = Date().timeIntervalSince(start)
        } else {
            actualDuration = sessionPlannedDuration - localTimerRemaining
        }

        let wasCompleted = localTimerRemaining <= 0

        let session = FocusSession(
            id: UUID(),
            userId: supabaseManager.currentUserId ?? UUID(),
            deviceId: DeviceInfo.currentDeviceId,
            startTime: localTimerStart ?? Date().addingTimeInterval(-actualDuration),
            endTime: Date(),
            plannedDurationSeconds: Int(sessionPlannedDuration),
            actualDurationSeconds: Int(actualDuration),
            wasCompleted: wasCompleted,
            blockedWebsiteCount: websiteSyncManager.blockedWebsites.count,
            blockedAppCount: MacAppBlocker.shared.blockedBundleIds.count,
            blockedWebsites: Array(websiteSyncManager.domains),
            modeName: modeManager.selectedMode?.name
        )

        statsManager.recordSession(session)

        Task {
            await sessionSyncManager.saveSession(session)
        }

        // Check for bonus reward (variable rewards system)
        // Only show popup if minimal mode is disabled
        if localPreferences.shouldShowRewardPopups {
            if let reward = rewardManager.checkForReward(
                session: session,
                currentStreak: statsManager.currentStreak,
                wasCompleted: wasCompleted
            ) {
                earnedReward = reward
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingRewardPopup = true
                }
            }
        }

        // Check for level up and achievements (show after reward popup)
        // Only show celebrations if minimal mode is disabled
        if !localPreferences.isMinimalModeEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                checkForCelebrations()
            }
        }

        // Show session review after celebrations
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showingSessionReview = true
        }

        localTimerActive = false
        localTimerStart = nil
        localTimerEnd = nil
        localTimerRemaining = 0
        localTimerTask?.cancel()
        localTimerTask = nil
        sessionIsStrict = false
        sessionPlannedDuration = 0

        blockEnforcementManager.stopEnforcement()
    }
}

// MARK: - Mode Pill Mac

struct ModePillMac: View {
    let mode: FocusMode
    let isSelected: Bool
    let onTap: () -> Void

    private var modeColor: Color {
        Color(hex: mode.color)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 12, weight: .medium))

                Text(mode.name)
                    .font(.system(size: 13, weight: .semibold))

                if mode.isStrictMode {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                }
            }
            .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(mode.modeGradient)
                } else {
                    Capsule()
                        .fill(DesignSystem.Colors.backgroundCard)
                        .overlay {
                            Capsule()
                                .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Schedule Pill Mac

struct SchedulePillMac: View {
    let schedule: FocusSchedule
    let isSelected: Bool
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if isActive {
                    Circle()
                        .fill(DesignSystem.Colors.success)
                        .frame(width: 6, height: 6)
                }

                Text(schedule.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textPrimary)

                if schedule.isStrictMode {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : schedule.primaryColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(schedule.gradient)
                } else {
                    Capsule()
                        .fill(DesignSystem.Colors.backgroundCard)
                        .overlay {
                            Capsule()
                                .strokeBorder(schedule.primaryColor.opacity(0.4), lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Schedule Ended View

struct ScheduleEndedView: View {
    let schedule: FocusSchedule
    let onResume: () -> Void
    let onTakeBreak: (TimeInterval) -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedBreakDuration: TimeInterval = 5 * 60

    private let breakOptions: [(String, TimeInterval)] = [
        ("5 min", 5 * 60),
        ("10 min", 10 * 60),
        ("15 min", 15 * 60),
        ("30 min", 30 * 60)
    ]

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Header
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 56, weight: .thin))
                        .foregroundStyle(schedule.primaryColor)

                    Text("Schedule Paused")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("\(schedule.name) has been paused until \(schedule.endTime.formatted)")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Options
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Resume button
                    Text("Resume Schedule")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                        .background {
                            Capsule()
                                .fill(schedule.gradient)
                        }
                        .contentShape(Capsule())
                        .onTapGesture {
                            dismiss()
                            onResume()
                        }

                    // Take a break section
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Or take a quick break")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(breakOptions, id: \.1) { option in
                                Text(option.0)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(selectedBreakDuration == option.1 ? .white : DesignSystem.Colors.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background {
                                        Capsule()
                                            .fill(selectedBreakDuration == option.1 ? schedule.primaryColor : DesignSystem.Colors.backgroundCard)
                                    }
                                    .overlay {
                                        Capsule()
                                            .strokeBorder(selectedBreakDuration == option.1 ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
                                    }
                                    .onTapGesture {
                                        selectedBreakDuration = option.1
                                    }
                            }
                        }

                        Text("Start Break")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background {
                                Capsule()
                                    .fill(DesignSystem.Colors.backgroundCard)
                            }
                            .overlay {
                                Capsule()
                                    .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                            }
                            .contentShape(Capsule())
                            .onTapGesture {
                                dismiss()
                                onTakeBreak(selectedBreakDuration)
                            }
                            .padding(.top, DesignSystem.Spacing.xs)
                    }

                    // Dismiss
                    Text("Dismiss")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .onTapGesture {
                            dismiss()
                            onDismiss()
                        }
                        .padding(.top, DesignSystem.Spacing.sm)
                }
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .padding(DesignSystem.Spacing.lg)
        }
    }
}
#endif
