import SwiftUI

/// Clean emergency exit confirmation for strict mode sessions
/// Psychology: Not guilt-tripping, just factual. User has committed, now they're paying to break it.
/// Hidden feature - not advertised, price escalates with each use.
struct EmergencyExitView: View {
    let sessionId: UUID
    let focusedTime: TimeInterval
    let remainingTime: TimeInterval
    let onConfirmExit: () -> Void
    let onCancel: () -> Void
    var modeColor: Color = DesignSystem.Colors.accent

    @StateObject private var hardModeManager = HardModeManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    @State private var isPurchasing = false
    @State private var showConfirmation = false

    var body: some View {
        ZStack {
            // Dark background with subtle gradient
            LinearGradient(
                colors: [
                    Color(hex: "0A0A10"),
                    Color(hex: "12121A")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Commitment badge
                commitmentBadge

                // Main message
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("Emergency Exit")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Text("End this session early for a one-time fee.")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Pattern warning (if applicable)
                if let warning = hardModeManager.patternWarning {
                    patternWarningBadge(warning)
                }

                // Escalation warning (if not first exit this month)
                if hardModeManager.config.exitsUsedThisMonth > 0 {
                    escalationBadge
                }

                // Action buttons
                actionButtons

                // Monthly reset info
                monthlyResetBadge
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .confirmationDialog(
            "Confirm Emergency Exit",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Pay \(exitPrice) to Exit", role: .destructive) {
                purchaseExit()
            }
            Button("Keep Focusing", role: .cancel) {}
        } message: {
            Text("You'll be charged \(exitPrice). This action cannot be undone.")
        }
        #if os(iOS)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        #endif
    }

    // MARK: - Commitment Badge

    private var commitmentBadge: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Circular progress showing time invested
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: commitmentProgress)
                    .stroke(
                        modeColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(formattedFocusedTime)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text("focused")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }

            // Remaining time info
            if remainingTime > 0 {
                Text("\(formattedRemainingTime) remaining")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Keep focusing (primary action)
            Button {
                onCancel()
            } label: {
                Text("Keep Focusing")
            }
            .buttonStyle(FrostedButtonStyle(isProminent: true))

            // Emergency exit (secondary, requires payment)
            Button {
                showConfirmation = true
            } label: {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "escape")
                            .font(.system(size: 14))
                        Text("Exit for \(exitPrice)")
                    }
                }
            }
            .buttonStyle(FrostedButtonStyle(isProminent: false))
            .disabled(isPurchasing)
        }
    }

    // MARK: - Pattern Warning

    private func patternWarningBadge(_ message: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.caution)

            Text(message)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.caution)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background {
            Capsule()
                .fill(DesignSystem.Colors.caution.opacity(0.1))
        }
    }

    // MARK: - Escalation Badge

    private var escalationBadge: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.warning)

            Text("Price increases to \(hardModeManager.config.nextExitPriceFormatted) after this exit")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.warning)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background {
            Capsule()
                .fill(DesignSystem.Colors.warning.opacity(0.1))
        }
    }

    // MARK: - Monthly Reset Badge

    private var monthlyResetBadge: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "calendar")
                .font(.system(size: 11))

            Text("Price resets to $2 next month")
                .font(DesignSystem.Typography.caption)
        }
        .foregroundStyle(DesignSystem.Colors.textMuted)
    }

    // MARK: - Computed Properties

    private var commitmentProgress: Double {
        let total = focusedTime + remainingTime
        guard total > 0 else { return 0 }
        return min(1.0, focusedTime / total)
    }

    private var formattedFocusedTime: String {
        let minutes = Int(focusedTime) / 60
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return String(format: "%d:%02d", hours, mins)
        }
        return "\(minutes)m"
    }

    private var formattedRemainingTime: String {
        let minutes = Int(remainingTime) / 60
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(minutes) min"
    }

    private var exitPrice: String {
        // Use escalating price from config
        return hardModeManager.config.currentExitPriceFormatted
    }

    // MARK: - Actions

    private func purchaseExit() {
        isPurchasing = true

        Task { @MainActor in
            let success = await premiumManager.purchaseEmergencyExit()

            if success {
                // Record the exit usage
                hardModeManager.recordEmergencyExitUsed(
                    sessionId: sessionId,
                    focusedTime: focusedTime,
                    remainingTime: remainingTime
                )

                isPurchasing = false
                onConfirmExit()
            } else {
                isPurchasing = false
            }
        }
    }
}

#Preview {
    EmergencyExitView(
        sessionId: UUID(),
        focusedTime: 12 * 60,  // 12 minutes focused
        remainingTime: 18 * 60,  // 18 minutes remaining
        onConfirmExit: { print("Exit confirmed") },
        onCancel: { print("Cancelled") }
    )
}
