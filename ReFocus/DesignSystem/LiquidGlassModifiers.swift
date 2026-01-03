import SwiftUI

// MARK: - Dark Glass View Modifiers (Opal-inspired)

/// Dark glass card with subtle glow
struct LiquidGlassCard: ViewModifier {
    var cornerRadius: CGFloat
    var hasGlow: Bool

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
            }
            .shadow(
                color: hasGlow ? DesignSystem.Colors.accent.opacity(0.15) : .clear,
                radius: 20,
                x: 0,
                y: 8
            )
    }
}

/// Dark glass button with hover state
struct GlassButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
            }
    }
}

/// Small pill button
struct PillButtonStyle: ButtonStyle {
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.captionMedium)
            .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background {
                Capsule()
                    .fill(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : DesignSystem.Colors.border,
                        lineWidth: 1
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies dark glass card styling
    func liquidGlassCard(
        cornerRadius: CGFloat = DesignSystem.Radius.lg,
        hasGlow: Bool = false
    ) -> some View {
        modifier(LiquidGlassCard(cornerRadius: cornerRadius, hasGlow: hasGlow))
    }

    /// Applies glass button styling
    func glassButton() -> some View {
        modifier(GlassButton())
    }

    /// Standard card padding
    func cardPadding() -> some View {
        padding(DesignSystem.Spacing.lg)
    }

    /// Section header styling
    func sectionHeader() -> some View {
        self
            .font(DesignSystem.Typography.captionMedium)
            .foregroundStyle(DesignSystem.Colors.textTertiary)
            .textCase(.uppercase)
            .tracking(1)
    }

    /// Dark page background
    func darkBackground() -> some View {
        self
            .background(DesignSystem.Colors.background)
    }

    /// Accent glow effect
    func accentGlow(radius: CGFloat = 20) -> some View {
        self
            .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: radius)
    }
}

// MARK: - Timer Ring Component

struct TimerRing: View {
    var progress: Double // 0.0 to 1.0
    var size: CGFloat = DesignSystem.Sizes.timerRingSize
    var strokeWidth: CGFloat = DesignSystem.Sizes.timerRingStroke

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    DesignSystem.Colors.timerRingBackground,
                    lineWidth: strokeWidth
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    DesignSystem.Colors.accentGradient,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: DesignSystem.Colors.timerRingGlow,
                    radius: 8
                )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Icon Button Component

struct IconButton: View {
    let systemName: String
    let action: () -> Void
    var size: CGFloat = DesignSystem.Sizes.iconSize

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(DesignSystem.Colors.backgroundCard)
                }
                .overlay {
                    Circle()
                        .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
