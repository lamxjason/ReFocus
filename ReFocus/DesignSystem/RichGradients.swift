import SwiftUI

// MARK: - Cohesive Color System
// Design Philosophy:
// 1. ONE accent color that changes with selected mode
// 2. Consistent dark backgrounds everywhere
// 3. PRO badge: Always mint green, subtle, consistent
// 4. Gradients ONLY for mode selection pills
// 5. Cards use subtle elevation, not color

enum AppTheme {
    // MARK: - Core Palette (Never Changes)

    /// Near-black background
    static let background = Color(hex: "0A0A10")

    /// Slightly elevated card background
    static let cardBackground = Color(hex: "16161C")

    /// More elevated surface
    static let elevatedBackground = Color(hex: "1E1E26")

    /// Subtle border color
    static let border = Color(hex: "2A2A32")

    // MARK: - Text Colors

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8E93")
    static let textMuted = Color(hex: "48484A")

    // MARK: - PRO Badge (Always consistent)

    static let proBadgeBackground = Color(hex: "7DCEA0")
    static let proBadgeText = Color.black

    // MARK: - Status Colors

    static let success = Color(hex: "34C759")
    static let warning = Color(hex: "FF9500")
    static let error = Color(hex: "FF3B30")
}

// MARK: - Mode Accent Colors

/// Each mode has ONE accent color used throughout the UI
enum ModeAccent {
    case quickFocus    // Teal
    case deepWork      // Purple
    case pomodoro      // Coral/Orange
    case zen           // Sage green
    case night         // Deep blue
    case custom(Color) // User-defined

    var color: Color {
        switch self {
        case .quickFocus:
            return Color(hex: "4A9C8C")  // Teal
        case .deepWork:
            return Color(hex: "8B5CF6")  // Purple
        case .pomodoro:
            return Color(hex: "F97316")  // Orange
        case .zen:
            return Color(hex: "84CC16")  // Lime green
        case .night:
            return Color(hex: "3B82F6")  // Blue
        case .custom(let color):
            return color
        }
    }

    /// Subtle tint for backgrounds (10% opacity)
    var tint: Color {
        color.opacity(0.1)
    }

    /// Soft background (15% opacity)
    var soft: Color {
        color.opacity(0.15)
    }

    /// Gradient for mode pills only
    var gradient: LinearGradient {
        LinearGradient(
            colors: [
                color,
                color.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - FocusMode Extension

extension FocusMode {
    /// Get the accent based on mode color
    var accent: ModeAccent {
        // Use the effectiveGradient for consistency
        return .custom(primaryColor)
    }

    /// Simple gradient from mode color (for pills only)
    var modeGradient: LinearGradient {
        // Use effectiveGradient to respect themeGradient setting
        let theme = effectiveGradient
        return LinearGradient(
            colors: [
                Color(hex: theme.primaryHex),
                Color(hex: theme.secondaryHex)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - PRO Badge Component

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(AppTheme.proBadgeText)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(AppTheme.proBadgeBackground)
            }
    }
}

// MARK: - Accent-Aware Card

struct AccentCard<Content: View>: View {
    let accent: Color
    let isHighlighted: Bool
    @ViewBuilder let content: () -> Content

    init(
        accent: Color = DesignSystem.Colors.accent,
        isHighlighted: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.accent = accent
        self.isHighlighted = isHighlighted
        self.content = content
    }

    var body: some View {
        content()
            .padding(DesignSystem.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isHighlighted ? accent.opacity(0.1) : AppTheme.cardBackground)
            }
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .strokeBorder(accent.opacity(0.3), lineWidth: 1)
                }
            }
    }
}

// MARK: - Mode Pill (Gradient allowed here)

struct ModePill: View {
    let mode: FocusMode
    let isSelected: Bool
    let action: () -> Void

    private var modeColor: Color {
        mode.primaryColor
    }

    var body: some View {
        Button(action: action) {
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
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    // Gradient only when selected
                    Capsule()
                        .fill(mode.modeGradient)
                } else {
                    // Dark pill when not selected
                    Capsule()
                        .fill(AppTheme.cardBackground)
                        .overlay {
                            Capsule()
                                .strokeBorder(AppTheme.border, lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Frosted Button Style

struct FrostedButtonStyle: ButtonStyle {
    var isProminent: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isProminent ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if isProminent {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.white.opacity(0.95))
                } else {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Accent Button

struct AccentButton: View {
    let title: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(accent)
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Frosted Start Button

struct FrostedStartButton: View {
    let title: String
    var accentColor: Color = .white
    var isLocked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 28)
                    .fill(accentColor)
            }
            .shadow(color: accentColor.opacity(0.4), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Setting Row

struct SettingRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var showProBadge: Bool = false
    @ViewBuilder let trailing: () -> Content

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(iconColor.opacity(0.15))
                }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(AppTheme.textPrimary)

                    if showProBadge {
                        ProBadge()
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer()

            trailing()
        }
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(AppTheme.cardBackground)
        }
    }
}

// MARK: - Legacy Gradient Support (for backward compatibility)

enum RichGradients {
    static let coral = LinearGradient(
        colors: [Color(hex: "E8A87C"), Color(hex: "C38D7B")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ocean = LinearGradient(
        colors: [Color(hex: "1A5276"), Color(hex: "2C8B9E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let twilight = LinearGradient(
        colors: [Color(hex: "4A2C6A"), Color(hex: "6B3FA0")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let forest = LinearGradient(
        colors: [Color(hex: "2D5A3D"), Color(hex: "4A8C5C")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let midnight = LinearGradient(
        colors: [Color(hex: "1A2744"), Color(hex: "263860")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let sage = LinearGradient(
        colors: [Color(hex: "87A878"), Color(hex: "9BB88D")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let aurora = LinearGradient(
        colors: [Color(hex: "5B4A8C"), Color(hex: "4A9C8C")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sunset = LinearGradient(
        colors: [Color(hex: "C97B84"), Color(hex: "D4A5A5")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

#Preview("Cohesive Design") {
    ZStack {
        AppTheme.background.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 16) {
                // PRO Badge
                HStack {
                    Text("Premium Feature")
                        .foregroundStyle(.white)
                    ProBadge()
                }

                // Setting rows with consistent accent
                let accent = ModeAccent.quickFocus.color

                SettingRow(
                    icon: "lock.fill",
                    iconColor: accent,
                    title: "Session Lock",
                    subtitle: "Lock sessions with paid exit",
                    showProBadge: true
                ) {
                    Toggle("", isOn: .constant(true))
                        .tint(accent)
                }

                SettingRow(
                    icon: "shield.checkered",
                    iconColor: accent,
                    title: "Regret Prevention",
                    subtitle: "Auto-block during vulnerable hours"
                ) {
                    Toggle("", isOn: .constant(false))
                        .tint(accent)
                }

                // Accent button
                AccentButton(title: "Start Focus", accent: accent) {}
                    .padding(.top, 20)
            }
            .padding()
        }
    }
}
