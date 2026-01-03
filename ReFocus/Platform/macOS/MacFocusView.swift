import SwiftUI

#if os(macOS)
struct MacFocusView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var timerSyncManager: TimerSyncManager
    @EnvironmentObject var websiteSyncManager: WebsiteSyncManager
    @EnvironmentObject var blockEnforcementManager: BlockEnforcementManager
    @StateObject private var premiumManager = PremiumManager.shared

    @State private var selectedDuration: TimeInterval = 25 * 60
    @State private var showingPaywall = false
    @State private var isLoading = false

    // Local timer fallback
    @State private var localTimerActive = false
    @State private var localTimerEnd: Date?
    @State private var localTimerRemaining: TimeInterval = 0
    @State private var localTimerTask: Task<Void, Never>?
    @State private var sessionIsStrict = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Timer Card
                    timerCard

                    // Quick Actions
                    if !isTimerActive {
                        quickActionsGrid

                        // Strict mode toggle
                        strictModeToggle
                    }

                    // Strict mode warning when active
                    if isTimerActive && sessionIsStrict {
                        strictModeActiveIndicator
                    }

                    // Status Cards
                    statusCards
                }
                .padding(DesignSystem.Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
    }

    // MARK: - Computed Properties

    private var isTimerActive: Bool {
        localTimerActive || (timerSyncManager.timerState?.isActive ?? false)
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

    // MARK: - Views

    private var timerCard: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                TimerRing(
                    progress: isTimerActive ? currentProgress : 1.0,
                    size: 280,
                    strokeWidth: 16
                )

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(remainingTimeString)
                        .font(DesignSystem.Typography.timerLarge)
                        .monospacedDigit()
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .contentTransition(.numericText())

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        if sessionIsStrict && isTimerActive {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }

                        Text(isTimerActive ? (sessionIsStrict ? "locked" : "focusing") : "ready")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .textCase(.uppercase)
                            .tracking(2)
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.lg)

            // Action Button
            if isTimerActive {
                Button {
                    stopFocusSession()
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: sessionIsStrict ? "lock.fill" : "stop.fill")
                            Text(sessionIsStrict ? "Session Locked" : "End Session")
                        }
                        .frame(width: 200)
                    }
                }
                .buttonStyle(.destructive)
                .controlSize(.large)
                .disabled(isLoading || sessionIsStrict)
                .opacity(sessionIsStrict ? 0.5 : 1.0)
            } else {
                Button {
                    startFocusSession()
                } label: {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            if premiumManager.isStrictModeEnabled {
                                Image(systemName: "lock.fill")
                            }
                            Text("Start Focus")
                        }
                        .frame(width: 200)
                    }
                }
                .buttonStyle(.primary)
                .controlSize(.large)
                .disabled(isLoading)
            }
        }
        .padding(DesignSystem.Spacing.xxl)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .fill(DesignSystem.Colors.backgroundCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
        }
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

    // MARK: - Actions

    private func startFocusSession() {
        isLoading = true
        sessionIsStrict = premiumManager.isStrictModeEnabled

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

    // MARK: - Local Timer

    private func startLocalTimer() {
        localTimerActive = true
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
        localTimerActive = false
        localTimerEnd = nil
        localTimerRemaining = 0
        localTimerTask?.cancel()
        localTimerTask = nil
        sessionIsStrict = false

        blockEnforcementManager.stopEnforcement()
    }

    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("DURATION")
                .sectionHeader()

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                QuickStartCard(minutes: 15, selectedDuration: $selectedDuration)
                QuickStartCard(minutes: 25, selectedDuration: $selectedDuration)
                QuickStartCard(minutes: 45, selectedDuration: $selectedDuration)
                QuickStartCard(minutes: 60, selectedDuration: $selectedDuration)
            }
        }
    }

    private var statusCards: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            MacStatusCard(
                icon: "globe",
                title: "Websites",
                value: "\(websiteSyncManager.blockedWebsites.count)",
                subtitle: "blocked"
            )

            MacStatusCard(
                icon: "app.badge",
                title: "Apps",
                value: "\(MacAppBlocker.shared.blockedBundleIds.count)",
                subtitle: "blocked"
            )

            MacStatusCard(
                icon: "shield.fill",
                title: "Status",
                value: blockEnforcementManager.isEnforcing ? "Active" : "Ready",
                subtitle: "",
                valueColor: blockEnforcementManager.isEnforcing ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary
            )
        }
    }
}

struct QuickStartCard: View {
    let minutes: Int
    @Binding var selectedDuration: TimeInterval

    var isSelected: Bool {
        selectedDuration == TimeInterval(minutes * 60)
    }

    var body: some View {
        Button {
            withAnimation(DesignSystem.Animation.quick) {
                selectedDuration = TimeInterval(minutes * 60)
            }
        } label: {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("\(minutes)")
                    .font(DesignSystem.Typography.metric)
                    .foregroundStyle(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)

                Text("min")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isSelected ? DesignSystem.Colors.accentSubtle : DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .strokeBorder(
                        isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

struct MacStatusCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    var valueColor: Color = DesignSystem.Colors.textPrimary

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(DesignSystem.Colors.accent)

            Text(value)
                .font(DesignSystem.Typography.metric)
                .foregroundStyle(valueColor)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            Text(title)
                .font(DesignSystem.Typography.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundCard)
        }
    }
}
#endif
