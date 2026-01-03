import SwiftUI

// MARK: - Design Tokens

/// ReFocus Design System
/// Premium, restrained, professional - a personal operating system, not a habit coach
/// Dark-first interface with quiet confidence and deliberate restraint
enum DesignSystem {

    // MARK: - Colors (Professional Dark Mode)

    enum Colors {
        // Backgrounds - Deep, sophisticated blacks
        static let background = Color(hex: "000000")
        static let backgroundElevated = Color(hex: "0A0A0A")
        static let backgroundCard = Color(hex: "141414")
        static let backgroundCardHover = Color(hex: "1A1A1A")
        static let backgroundSubtle = Color(hex: "0F0F0F")

        // Primary Accent - Single, muted accent for key actions only
        // A sophisticated warm neutral that doesn't distract
        static let accent = Color(hex: "E8E4E0")  // Warm off-white for primary actions
        static let accentMuted = Color(hex: "A8A4A0")  // For secondary emphasis
        static let accentSubtle = Color(hex: "E8E4E0").opacity(0.12)

        // Status indicators - Muted, professional
        static let positive = Color(hex: "6B8E6B")   // Muted sage green
        static let caution = Color(hex: "C4A574")   // Muted gold
        static let negative = Color(hex: "B07070")  // Muted rose

        // Legacy aliases for compatibility
        static let success = positive
        static let warning = caution
        static let error = negative
        static let destructive = negative

        // Text - Precise hierarchy
        static let textPrimary = Color.white.opacity(0.92)
        static let textSecondary = Color.white.opacity(0.60)
        static let textTertiary = Color.white.opacity(0.40)
        static let textMuted = Color.white.opacity(0.25)

        // Borders - Subtle definition
        static let border = Color.white.opacity(0.08)
        static let borderSubtle = Color.white.opacity(0.04)
        static let borderFocused = Color.white.opacity(0.20)

        // Gradients - Used sparingly
        static let subtleGradient = LinearGradient(
            colors: [Color(hex: "141414"), Color(hex: "0A0A0A")],
            startPoint: .top,
            endPoint: .bottom
        )

        // Timer ring - Clean, professional
        static let timerRingBackground = Color.white.opacity(0.06)
        static let timerRingProgress = Color.white.opacity(0.90)

        // Soft glow for depth (use sparingly)
        static let softGlow = Color.white.opacity(0.03)

        // For mode colors (user customizable)
        static func modeAccent(_ hex: String) -> Color {
            Color(hex: hex)
        }

        // Legacy compatibility
        static let accentSoft = accentSubtle
        static let accentGlow = accent.opacity(0.3)
        static let accentGradient = LinearGradient(
            colors: [accent, accentMuted],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let timerRingGlow = Color.white.opacity(0.2)
    }

    // MARK: - Spacing (8pt Grid - Generous)

    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
        static let section: CGFloat = 40  // Between major sections
    }

    // MARK: - Corner Radius

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 9999
    }

    // MARK: - Typography (Modern, Neutral Sans-Serif)

    enum Typography {
        // Timer - Precise, authoritative numbers
        static let timerLarge = Font.system(size: 72, weight: .light, design: .default)
        static let timerMedium = Font.system(size: 56, weight: .light, design: .default)
        static let timerSmall = Font.system(size: 40, weight: .light, design: .default)

        // Headings - Clear hierarchy
        static let title = Font.system(size: 28, weight: .semibold, design: .default)
        static let headline = Font.system(size: 20, weight: .semibold, design: .default)
        static let subheadline = Font.system(size: 17, weight: .medium, design: .default)

        // Body - Clean, readable
        static let body = Font.system(size: 15, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 15, weight: .medium, design: .default)
        static let callout = Font.system(size: 14, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let captionMedium = Font.system(size: 12, weight: .medium, design: .default)

        // Numbers - Monospace for precision
        static let metric = Font.system(size: 32, weight: .medium, design: .monospaced)
        static let metricSmall = Font.system(size: 20, weight: .medium, design: .monospaced)
        static let metricLabel = Font.system(size: 11, weight: .medium, design: .default)

        // Labels - Uppercase tracking
        static let label = Font.system(size: 11, weight: .semibold, design: .default)

        // Button
        static let button = Font.system(size: 15, weight: .semibold, design: .default)
        static let buttonSmall = Font.system(size: 13, weight: .semibold, design: .default)
    }

    // MARK: - Animation (Subtle, Professional)

    enum Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.12)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.20)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.30)
        static let spring = SwiftUI.Animation.spring(response: 0.30, dampingFraction: 0.85)
        static let springSubtle = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.90)
    }

    // MARK: - Sizes

    enum Sizes {
        static let buttonHeight: CGFloat = 52
        static let buttonHeightSmall: CGFloat = 40
        static let buttonHeightCompact: CGFloat = 36
        static let iconSize: CGFloat = 20
        static let iconSizeSmall: CGFloat = 16
        static let timerRingSize: CGFloat = 260
        static let timerRingStroke: CGFloat = 4

        // macOS specific
        static let sidebarWidth: CGFloat = 220
        static let macMinWidth: CGFloat = 900
        static let macMinHeight: CGFloat = 600
    }

    // MARK: - Effects

    enum Effects {
        static let accentGlow = Colors.accent.opacity(0.3)
        static let softGlow = Colors.softGlow

        static func glow(color: Color = Colors.accent, radius: CGFloat = 20) -> some View {
            EmptyView()
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Professional Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(DesignSystem.Colors.background)
            .frame(height: DesignSystem.Sizes.buttonHeight)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.textMuted)
            }
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .frame(height: DesignSystem.Sizes.buttonHeight)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.backgroundCard)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                    }
            }
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

struct ColoredPrimaryButtonStyle: ButtonStyle {
    let color: Color
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(.white)
            .frame(height: DesignSystem.Sizes.buttonHeight)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isEnabled ? color : color.opacity(0.4))
            }
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(DesignSystem.Colors.negative)
            .frame(height: DesignSystem.Sizes.buttonHeight)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.negative.opacity(0.12))
            }
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}

// MARK: - Platform Compatibility

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
