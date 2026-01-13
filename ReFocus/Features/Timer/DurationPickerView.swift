import SwiftUI

struct DurationPickerView: View {
    @Binding var duration: TimeInterval
    @Environment(\.dismiss) var dismiss
    @StateObject private var modeManager = FocusModeManager.shared

    @State private var hours: Int = 0
    @State private var minutes: Int = 25

    private var modeColor: Color {
        guard let mode = modeManager.selectedMode else {
            return DesignSystem.Colors.accent
        }
        return Color(hex: mode.color)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Platform-specific picker
                    #if os(iOS)
                    // iOS: Wheel pickers
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        // Hours
                        VStack(spacing: DesignSystem.Spacing.xs) {
                            Text("HOURS")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)

                            Picker("Hours", selection: $hours) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour)")
                                        .tag(hour)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 100)
                            .clipped()
                        }

                        Text(":")
                            .font(DesignSystem.Typography.timerMedium)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .padding(.top, DesignSystem.Spacing.lg)

                        // Minutes
                        VStack(spacing: DesignSystem.Spacing.xs) {
                            Text("MINUTES")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)

                            Picker("Minutes", selection: $minutes) {
                                ForEach(0..<60, id: \.self) { minute in
                                    Text(String(format: "%02d", minute))
                                        .tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 100)
                            .clipped()
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                            .fill(DesignSystem.Colors.backgroundCard)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                            .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                    }
                    #else
                    // macOS: Custom inline picker with chevrons
                    MacInlineDurationPicker(
                        label: "",
                        hours: $hours,
                        minutes: $minutes,
                        accentColor: modeColor
                    )
                    #endif

                    // Quick presets
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("PRESETS")
                            .sectionHeader()
                            .padding(.horizontal, DesignSystem.Spacing.xs)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: DesignSystem.Spacing.sm) {
                            PresetButton(label: "5m", totalMinutes: 5, hours: $hours, minutes: $minutes, accentColor: modeColor)
                            PresetButton(label: "15m", totalMinutes: 15, hours: $hours, minutes: $minutes, accentColor: modeColor)
                            PresetButton(label: "25m", totalMinutes: 25, hours: $hours, minutes: $minutes, accentColor: modeColor)
                            PresetButton(label: "45m", totalMinutes: 45, hours: $hours, minutes: $minutes, accentColor: modeColor)
                            PresetButton(label: "1h", totalMinutes: 60, hours: $hours, minutes: $minutes, accentColor: modeColor)
                            PresetButton(label: "2h", totalMinutes: 120, hours: $hours, minutes: $minutes, accentColor: modeColor)
                        }
                    }

                    // Confirm button
                    Button {
                        duration = TimeInterval(hours * 3600 + minutes * 60)
                        dismiss()
                    } label: {
                        Text("Set Duration")
                    }
                    .buttonStyle(ColoredPrimaryButtonStyle(color: modeColor))
                    .padding(.top, DesignSystem.Spacing.sm)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .safeAreaInset(edge: .top) {
                // Custom title with proper spacing and background
                HStack {
                    Text("Duration")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.backgroundElevated)
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
            .onAppear {
                let totalMinutes = Int(duration / 60)
                hours = totalMinutes / 60
                minutes = totalMinutes % 60
            }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(DesignSystem.Colors.backgroundElevated)
        #endif
    }
}

struct PresetButton: View {
    let label: String
    let totalMinutes: Int
    @Binding var hours: Int
    @Binding var minutes: Int
    var accentColor: Color = DesignSystem.Colors.accent

    private var isSelected: Bool {
        hours * 60 + minutes == totalMinutes
    }

    var body: some View {
        Button {
            withAnimation(DesignSystem.Animation.quick) {
                hours = totalMinutes / 60
                minutes = totalMinutes % 60
            }
        } label: {
            Text(label)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                .fill(isSelected ? accentColor : DesignSystem.Colors.backgroundCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                .strokeBorder(
                    isSelected ? Color.clear : DesignSystem.Colors.border,
                    lineWidth: 1
                )
        }
    }
}

#Preview {
    DurationPickerView(duration: .constant(25 * 60))
}
