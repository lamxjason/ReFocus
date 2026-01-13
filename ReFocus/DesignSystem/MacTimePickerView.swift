import SwiftUI

#if os(macOS)
/// Beautiful inline time picker for macOS - always visible, easy to use
struct MacInlineTimePicker: View {
    let label: String
    @Binding var time: Date
    var accentColor: Color = DesignSystem.Colors.accent

    @State private var selectedHour: Int
    @State private var selectedMinute: Int
    @State private var isPM: Bool

    init(label: String, time: Binding<Date>, accentColor: Color = DesignSystem.Colors.accent) {
        self.label = label
        self._time = time
        self.accentColor = accentColor

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time.wrappedValue)
        let hour24 = components.hour ?? 9
        let minute = components.minute ?? 0

        var hour12 = hour24 % 12
        if hour12 == 0 { hour12 = 12 }

        _selectedHour = State(initialValue: hour12)
        _selectedMinute = State(initialValue: minute)
        _isPM = State(initialValue: hour24 >= 12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            HStack(spacing: 0) {
                // Hour
                TimeColumnPicker(
                    values: Array(1...12),
                    selected: $selectedHour,
                    accentColor: accentColor,
                    format: { "\($0)" }
                )
                .onChange(of: selectedHour) { _, _ in updateTime() }

                Text(":")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 2)

                // Minute
                TimeColumnPicker(
                    values: Array(0...59),
                    selected: $selectedMinute,
                    accentColor: accentColor,
                    format: { String(format: "%02d", $0) }
                )
                .onChange(of: selectedMinute) { _, _ in updateTime() }

                // AM/PM
                VStack(spacing: 4) {
                    TimeSegmentButton(text: "AM", isSelected: !isPM, accentColor: accentColor) {
                        isPM = false
                        updateTime()
                    }
                    TimeSegmentButton(text: "PM", isSelected: isPM, accentColor: accentColor) {
                        isPM = true
                        updateTime()
                    }
                }
                .padding(.leading, 12)
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

    private func updateTime() {
        var hour24 = selectedHour
        if !isPM && hour24 == 12 {
            hour24 = 0
        } else if isPM && hour24 != 12 {
            hour24 += 12
        }

        var components = DateComponents()
        components.hour = hour24
        components.minute = selectedMinute

        if let newDate = Calendar.current.date(from: components) {
            time = newDate
        }
    }
}

/// Individual column picker with increment/decrement buttons
struct TimeColumnPicker: View {
    let values: [Int]
    @Binding var selected: Int
    var accentColor: Color
    let format: (Int) -> String

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
                    .frame(width: 44, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Value display
            Text(format(selected))
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(width: 44, height: 36)
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
                    .frame(width: 44, height: 24)
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
        }
    }

    private func decrement() {
        if let currentIndex = values.firstIndex(of: selected) {
            let prevIndex = (currentIndex - 1 + values.count) % values.count
            selected = values[prevIndex]
        }
    }
}

/// AM/PM segment button
struct TimeSegmentButton: View {
    let text: String
    let isSelected: Bool
    var accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textMuted)
                .frame(width: 36, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? accentColor : DesignSystem.Colors.backgroundElevated)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            MacInlineTimePicker(label: "Start", time: .constant(Date()), accentColor: .purple)
            MacInlineTimePicker(label: "End", time: .constant(Date()), accentColor: .purple)
        }
    }
    .padding(32)
    .background(DesignSystem.Colors.background)
    .frame(width: 500)
}
#endif
