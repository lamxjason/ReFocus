import SwiftUI

/// View for creating or editing a focus schedule
struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scheduleManager = ScheduleManager.shared

    @State private var name: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedDays: Set<Weekday>
    @State private var isStrictMode: Bool
    @State private var selectedGradient: ThemeGradient

    private let existingSchedule: FocusSchedule?
    private let isEditing: Bool

    init(schedule: FocusSchedule? = nil) {
        self.existingSchedule = schedule
        self.isEditing = schedule != nil

        let s = schedule ?? .default
        _name = State(initialValue: s.name)
        _startTime = State(initialValue: s.startTime.date)
        _endTime = State(initialValue: s.endTime.date)
        _selectedDays = State(initialValue: s.days)
        _isStrictMode = State(initialValue: s.isStrictMode)
        _selectedGradient = State(initialValue: s.themeGradient)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Name
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("SCHEDULE NAME")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)

                            TextField("e.g. Work Hours", text: $name)
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                        .fill(DesignSystem.Colors.backgroundCard)
                                }
                        }

                        // Color picker
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("COLOR THEME")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)

                            gradientPicker
                        }

                        // Days selector
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("ACTIVE DAYS")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)

                            daysPicker
                        }

                        // Time pickers
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("FOCUS HOURS")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)

                            HStack(spacing: DesignSystem.Spacing.md) {
                                timePickerCard(label: "Start", time: $startTime)
                                timePickerCard(label: "End", time: $endTime)
                            }
                        }

                        // Strict mode toggle
                        strictModeRow

                        // Duration preview
                        durationPreview
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "Edit Schedule" : "New Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .disabled(!isValid)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Gradient Picker

    private var selectedColor: Color {
        Color(hex: selectedGradient.primaryHex)
    }

    private var gradientPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(ThemeGradient.allCases, id: \.self) { gradient in
                    gradientButton(gradient)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func gradientButton(_ gradient: ThemeGradient) -> some View {
        let isSelected = selectedGradient == gradient

        return Button {
            withAnimation(DesignSystem.Animation.quick) {
                selectedGradient = gradient
            }
        } label: {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: gradient.primaryHex),
                            Color(hex: gradient.secondaryHex),
                            Color(hex: gradient.tertiaryHex)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(.white, lineWidth: 3)
                    }
                }
                .shadow(color: Color(hex: gradient.primaryHex).opacity(isSelected ? 0.5 : 0), radius: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Days Picker

    private var daysPicker: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Quick select buttons
            HStack(spacing: DesignSystem.Spacing.sm) {
                quickSelectButton("Weekdays", days: Set(Weekday.weekdays))
                quickSelectButton("Weekend", days: Set(Weekday.weekend))
                quickSelectButton("Every Day", days: Set(Weekday.allCases))
            }

            // Individual day buttons
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(Weekday.allCases) { day in
                    dayButton(day)
                }
            }
        }
    }

    private func quickSelectButton(_ label: String, days: Set<Weekday>) -> some View {
        let isSelected = selectedDays == days

        return Button {
            withAnimation(DesignSystem.Animation.quick) {
                selectedDays = days
            }
        } label: {
            Text(label)
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background {
                    Capsule()
                        .fill(isSelected ? selectedColor : DesignSystem.Colors.backgroundCard)
                }
                .overlay {
                    if !isSelected {
                        Capsule()
                            .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func dayButton(_ day: Weekday) -> some View {
        let isSelected = selectedDays.contains(day)

        return Button {
            withAnimation(DesignSystem.Animation.quick) {
                if isSelected {
                    selectedDays.remove(day)
                } else {
                    selectedDays.insert(day)
                }
            }
        } label: {
            Text(day.initial)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textPrimary)
                .frame(width: 40, height: 40)
                .background {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: selectedGradient.primaryHex),
                                        Color(hex: selectedGradient.secondaryHex)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        Circle()
                            .fill(DesignSystem.Colors.backgroundCard)
                    }
                }
                .overlay {
                    if !isSelected {
                        Circle()
                            .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time Picker

    private func timePickerCard(label: String, time: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(DesignSystem.Colors.accent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundCard)
        }
    }

    // MARK: - Strict Mode

    private var strictModeRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(selectedColor)

                    Text("Strict Mode")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                }

                Text("Cannot be disabled during scheduled hours")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: $isStrictMode)
                .tint(selectedColor)
                .labelsHidden()
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundCard)
        }
    }

    // MARK: - Duration Preview

    private var durationPreview: some View {
        let duration = calculateDuration()

        return VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .thin))
                .foregroundStyle(selectedColor)

            Text("\(duration) of focused time")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text(selectedDays.isEmpty ? "Select days to schedule" : daysDescription)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: selectedGradient.primaryHex).opacity(0.2),
                            Color(hex: selectedGradient.secondaryHex).opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(selectedColor.opacity(0.3), lineWidth: 1)
        }
    }

    private var daysDescription: String {
        if selectedDays == Set(Weekday.weekdays) {
            return "Every weekday"
        } else if selectedDays == Set(Weekday.weekend) {
            return "Every weekend"
        } else if selectedDays == Set(Weekday.allCases) {
            return "Every day"
        } else {
            return selectedDays.sorted { $0.rawValue < $1.rawValue }
                .map { $0.shortName }
                .joined(separator: ", ")
        }
    }

    private func calculateDuration() -> String {
        let start = TimeComponents.from(date: startTime)
        let end = TimeComponents.from(date: endTime)

        guard start < end else { return "0 hours" }

        let minutes = end.totalMinutes - start.totalMinutes
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 && remainingMinutes > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else if hours > 0 {
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        } else {
            return "\(remainingMinutes) minutes"
        }
    }

    // MARK: - Validation & Save

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedDays.isEmpty &&
        TimeComponents.from(date: startTime) < TimeComponents.from(date: endTime)
    }

    private func saveSchedule() {
        let schedule = FocusSchedule(
            id: existingSchedule?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            startTime: TimeComponents.from(date: startTime),
            endTime: TimeComponents.from(date: endTime),
            days: selectedDays,
            isEnabled: existingSchedule?.isEnabled ?? true,
            isStrictMode: isStrictMode,
            focusModeId: nil,
            themeGradient: selectedGradient
        )

        if isEditing {
            scheduleManager.updateSchedule(schedule)
        } else {
            scheduleManager.addSchedule(schedule)
        }

        dismiss()
    }
}

#Preview {
    ScheduleEditorView()
}
