import SwiftUI

/// Full-screen protection overlay shown when Regret Prevention is active
struct RegretPreventionView: View {
    @StateObject private var regretManager = RegretPreventionManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var breatheScale: CGFloat = 1.0
    @State private var currentQuote: Quote = MotivationalQuotes.randomForDelay()
    @State private var quoteOpacity: Double = 1.0
    @State private var displayedRemaining: String = ""

    private let quoteChangeInterval: TimeInterval = 8

    var body: some View {
        ZStack {
            // Rich background gradient based on protection type
            protectionGradient
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Protection icon with breathing animation
                protectionIcon

                // Header
                headerSection

                Spacer()

                // Quote
                quoteSection

                Spacer()

                // Status and actions
                actionSection
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .onAppear {
            startBreathingAnimation()
            startQuoteRotation()
            startRemainingTimeUpdates()
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
        #endif
    }

    // MARK: - Protection Icon

    private var protectionIcon: some View {
        ZStack {
            // Outer glow with gradient
            Circle()
                .fill(protectionColor.opacity(0.15))
                .frame(width: 150, height: 150)
                .scaleEffect(breatheScale)
                .blur(radius: 10)

            // Inner circle with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                protectionColor.opacity(0.4),
                                protectionColor.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)

                Circle()
                    .strokeBorder(protectionColor.opacity(0.5), lineWidth: 2)
                    .frame(width: 110, height: 110)

                // Icon
                Image(systemName: regretManager.activeProtection?.icon ?? "shield.checkered")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Text(headerTitle)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text(regretManager.activeProtection?.message ?? "Protection is active")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            // Remaining time badge (for post-session)
            if !displayedRemaining.isEmpty {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))

                    Text(displayedRemaining)
                        .font(DesignSystem.Typography.captionMedium)
                }
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background {
                    Capsule()
                        .fill(DesignSystem.Colors.backgroundCard)
                }
                .padding(.top, DesignSystem.Spacing.xs)
            }
        }
    }

    private var headerTitle: String {
        guard let protection = regretManager.activeProtection else {
            return "Protection Active"
        }

        switch protection.window.type {
        case .lateNight:
            return "Late Night Protection"
        case .postSession:
            return "Stay Protected"
        case .custom:
            return protection.window.name
        }
    }

    private var protectionColor: Color {
        guard let protection = regretManager.activeProtection else {
            return DesignSystem.Colors.accent
        }

        switch protection.window.type {
        case .lateNight:
            return Color(hex: "6B3FA0")  // Twilight purple
        case .postSession:
            return Color(hex: "4A8C5C")  // Forest green
        case .custom:
            return Color(hex: "2C8B9E")  // Ocean teal
        }
    }

    private var protectionGradient: some View {
        Group {
            if let protection = regretManager.activeProtection {
                switch protection.window.type {
                case .lateNight:
                    LinearGradient(
                        colors: [
                            Color(hex: "0A0A10"),
                            Color(hex: "2D1B4E"),
                            Color(hex: "4A2C6A").opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                case .postSession:
                    LinearGradient(
                        colors: [
                            Color(hex: "0A0A10"),
                            Color(hex: "1A2D1F"),
                            Color(hex: "2D5A3D").opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                case .custom:
                    LinearGradient(
                        colors: [
                            Color(hex: "0A0A10"),
                            Color(hex: "1A5276"),
                            Color(hex: "2C8B9E").opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            } else {
                LinearGradient(
                    colors: [
                        Color(hex: "0A0A10"),
                        Color(hex: "12121A")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    // MARK: - Quote Section

    private var quoteSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text(currentQuote.text)
                .font(.system(size: 17, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            if let author = currentQuote.author {
                Text("— \(author)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xl)
        .opacity(quoteOpacity)
        .frame(height: 100)
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Info text based on protection type
            infoText

            // Actions
            if isPostSessionProtection {
                // Can dismiss post-session early (but discouraged)
                Button {
                    regretManager.cancelPostSessionProtection()
                    dismiss()
                } label: {
                    Text("End Protection Early")
                }
                .buttonStyle(.secondary)
            }

            // Acknowledge button (doesn't dismiss for time windows)
            Button {
                if isPostSessionProtection {
                    dismiss()
                }
                // For time windows, this just acknowledges but keeps protection active
            } label: {
                Text(isPostSessionProtection ? "Keep Me Protected" : "I Understand")
            }
            .buttonStyle(.primary)
        }
        .padding(.bottom, DesignSystem.Spacing.xxl)
    }

    private var infoText: some View {
        Group {
            if let protection = regretManager.activeProtection {
                switch protection.reason {
                case .timeWindow:
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("Protection will end automatically")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textMuted)

                        if let window = regretManager.config.windows.first(where: { $0.id == protection.window.id }),
                           let endTime = window.endTime {
                            Text("at \(endTime.displayString)")
                                .font(DesignSystem.Typography.captionMedium)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }

                case .postSession:
                    Text("This window helps you maintain focus after deep work")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var isPostSessionProtection: Bool {
        if case .postSession = regretManager.activeProtection?.reason {
            return true
        }
        return false
    }

    // MARK: - Animations

    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: 4)
            .repeatForever(autoreverses: true)
        ) {
            breatheScale = 1.15
        }
    }

    private func startQuoteRotation() {
        Task { @MainActor in
            while regretManager.isProtectionActive {
                try? await Task.sleep(for: .seconds(quoteChangeInterval))
                guard regretManager.isProtectionActive else { break }

                withAnimation(.easeInOut(duration: 0.4)) {
                    quoteOpacity = 0
                }

                try? await Task.sleep(for: .milliseconds(400))
                currentQuote = MotivationalQuotes.randomForDelay()

                withAnimation(.easeInOut(duration: 0.4)) {
                    quoteOpacity = 1
                }
            }
        }
    }

    private func startRemainingTimeUpdates() {
        Task { @MainActor in
            while regretManager.isProtectionActive {
                displayedRemaining = regretManager.formattedPostSessionRemaining ?? ""
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

#Preview {
    RegretPreventionView()
}
