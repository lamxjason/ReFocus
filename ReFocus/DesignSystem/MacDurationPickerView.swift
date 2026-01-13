import SwiftUI

#if os(macOS)
/// Beautiful inline duration picker for macOS - matches the time picker style
struct MacInlineDurationPicker: View {
    let label: String
    @Binding var hours: Int
    @Binding var minutes: Int
    var accentColor: Color = DesignSystem.Colors.accent
    var maxHours: Int = 23
    var minuteStep: Int = 1  // Can be 1, 5, 15, etc.

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if !label.isEmpty {
                Text(label)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            HStack(spacing: 0) {
                // Hours
                DurationColumnPicker(
                    values: Array(0...maxHours),
                    selected: $hours,
                    accentColor: accentColor,
                    format: { "\($0)" },
                    suffix: "h"
                )

                Text(":")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 4)

                // Minutes
                DurationColumnPicker(
                    values: minuteValues,
                    selected: $minutes,
                    accentColor: accentColor,
                    format: { String(format: "%02d", $0) },
                    suffix: "m"
                )
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var minuteValues: [Int] {
        stride(from: 0, to: 60, by: minuteStep).map { $0 }
    }
}

/// Individual column picker with increment/decrement buttons for duration
struct DurationColumnPicker: View {
    let values: [Int]
    @Binding var selected: Int
    var accentColor: Color
    let format: (Int) -> String
    var suffix: String = ""

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 2) {
            // Up button
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    increment()
                }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isHovered ? accentColor : DesignSystem.Colors.textMuted)
                    .frame(width: 52, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Value display
            HStack(spacing: 2) {
                Text(format(selected))
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
            }
            .frame(width: 52, height: 36)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accentColor.opacity(0.15))
            }

            // Down button
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    decrement()
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isHovered ? accentColor : DesignSystem.Colors.textMuted)
                    .frame(width: 52, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func increment() {
        if let currentIndex = values.firstIndex(of: selected) {
            let nextIndex = (currentIndex + 1) % values.count
            selected = values[nextIndex]
        } else {
            // Value not in list, snap to nearest
            selected = values.first ?? 0
        }
    }

    private func decrement() {
        if let currentIndex = values.firstIndex(of: selected) {
            let prevIndex = (currentIndex - 1 + values.count) % values.count
            selected = values[prevIndex]
        } else {
            // Value not in list, snap to nearest
            selected = values.first ?? 0
        }
    }
}

/// Time-of-day picker (24h format) for macOS - uses hour:minute integers directly
struct MacInlineTimeOfDayPicker: View {
    let label: String
    @Binding var hour: Int
    @Binding var minute: Int
    var accentColor: Color = DesignSystem.Colors.accent
    var minuteStep: Int = 15  // Typically 15 for time ranges

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if !label.isEmpty {
                Text(label)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            HStack(spacing: 0) {
                // Hours (0-23)
                DurationColumnPicker(
                    values: Array(0...23),
                    selected: $hour,
                    accentColor: accentColor,
                    format: { String(format: "%02d", $0) },
                    suffix: ""
                )

                Text(":")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 4)

                // Minutes
                DurationColumnPicker(
                    values: minuteValues,
                    selected: $minute,
                    accentColor: accentColor,
                    format: { String(format: "%02d", $0) },
                    suffix: ""
                )
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private var minuteValues: [Int] {
        stride(from: 0, to: 60, by: minuteStep).map { $0 }
    }
}

#Preview {
    VStack(spacing: 24) {
        MacInlineDurationPicker(
            label: "Duration",
            hours: .constant(1),
            minutes: .constant(30),
            accentColor: .purple
        )

        MacInlineDurationPicker(
            label: "",
            hours: .constant(0),
            minutes: .constant(25),
            accentColor: .blue,
            minuteStep: 5
        )

        MacInlineTimeOfDayPicker(
            label: "Start",
            hour: .constant(9),
            minute: .constant(0),
            accentColor: .orange
        )
    }
    .padding(32)
    .background(DesignSystem.Colors.background)
    .frame(width: 300)
}
#endif
