import SwiftUI

/// Displays the number of streak freezes available
struct StreakFreezeIndicator: View {
    let freezesAvailable: Int
    var compact: Bool = false

    var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }

    private var compactView: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "snowflake")
                .font(.system(size: 12))
                .foregroundStyle(.cyan)

            Text("\(freezesAvailable)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(Color.cyan.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var fullView: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: "snowflake")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.cyan)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Streak Freezes")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(index < freezesAvailable ? Color.cyan : Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
            }

            Spacer()

            Text("\(freezesAvailable)/5")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.cyan)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(Color.cyan.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Full - 3 Freezes") {
    VStack(spacing: DesignSystem.Spacing.md) {
        StreakFreezeIndicator(freezesAvailable: 3)
        StreakFreezeIndicator(freezesAvailable: 0)
        StreakFreezeIndicator(freezesAvailable: 5)
    }
    .padding()
    .background(Color.black)
}

#Preview("Compact") {
    HStack(spacing: DesignSystem.Spacing.md) {
        StreakFreezeIndicator(freezesAvailable: 2, compact: true)
        StreakFreezeIndicator(freezesAvailable: 0, compact: true)
    }
    .padding()
    .background(Color.black)
}
#endif
