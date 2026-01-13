import SwiftUI

/// Banner that warns users when their streak is at risk
struct StreakWarningBanner: View {
    let currentStreak: Int
    let hoursRemaining: Int
    var freezesAvailable: Int = 0
    var onStartSession: (() -> Void)?
    var onUseFreeze: (() -> Void)?

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Warning icon with pulse animation
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .scaleEffect(isPulsing ? 1.2 : 1.0)
                        .opacity(isPulsing ? 0 : 1)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Streak at risk!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    Text(warningMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                if let onStartSession = onStartSession {
                    Button(action: onStartSession) {
                        Text("Focus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
            }

            // Streak freeze option
            if freezesAvailable > 0 {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 14))
                        .foregroundStyle(.cyan)

                    Text("\(freezesAvailable) freeze\(freezesAvailable == 1 ? "" : "s") available")
                        .font(.system(size: 13))
                        .foregroundStyle(.cyan.opacity(0.8))

                    Spacer()

                    if let onUseFreeze = onUseFreeze {
                        Button(action: onUseFreeze) {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "snowflake")
                                    .font(.system(size: 12))
                                Text("Use Freeze")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(
                                Capsule()
                                    .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.top, DesignSystem.Spacing.xs)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.15),
                            Color.red.opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var warningMessage: String {
        if hoursRemaining <= 1 {
            return "\(currentStreak) day streak ends soon!"
        } else if hoursRemaining <= 6 {
            return "\(currentStreak) day streak ends in \(hoursRemaining)h"
        } else {
            return "Complete a session to keep your \(currentStreak) day streak"
        }
    }
}

// MARK: - Compact Version

struct StreakWarningPill: View {
    let currentStreak: Int

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)

            Text("\(currentStreak)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            Text("at risk")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Banner with Freezes") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        StreakWarningBanner(
            currentStreak: 7,
            hoursRemaining: 4,
            freezesAvailable: 2,
            onStartSession: {},
            onUseFreeze: {}
        )

        StreakWarningBanner(
            currentStreak: 14,
            hoursRemaining: 1,
            freezesAvailable: 0,
            onStartSession: {}
        )
    }
    .padding()
    .background(Color.black)
}

#Preview("Pill") {
    StreakWarningPill(currentStreak: 14)
        .padding()
        .background(Color.black)
}
#endif
