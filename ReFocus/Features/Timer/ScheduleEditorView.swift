import SwiftUI
#if os(iOS)
import FamilyControls
#endif

/// View for creating or editing a focus schedule
struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scheduleManager = ScheduleManager.shared
    @StateObject private var premiumManager = PremiumManager.shared

    @State private var name: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var selectedDays: Set<Weekday>
    @State private var isStrictMode: Bool
    @State private var selectedGradient: ThemeGradient

    // App and website blocking
    @State private var appSelectionData: Data?
    @State private var websiteDomains: [String]
    @State private var newWebsite: String = ""
    @State private var showingAppPicker = false

    @State private var showingPaywall = false
    @State private var showingStrictModeWarning = false
    @State private var showingDeleteConfirm = false

    #if os(iOS)
    @State private var familyActivitySelection = FamilyActivitySelection()
    #endif

    private let existingSchedule: FocusSchedule?
    private let isEditing: Bool
    private let onSave: (() -> Void)?
    private let onCancel: (() -> Void)?

    init(schedule: FocusSchedule? = nil, onSave: (() -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.existingSchedule = schedule
        self.isEditing = schedule != nil
        self.onSave = onSave
        self.onCancel = onCancel

        let s = schedule ?? .default
        _name = State(initialValue: s.name)
        _startTime = State(initialValue: s.startTime.date)
        _endTime = State(initialValue: s.endTime.date)
        _selectedDays = State(initialValue: s.days)
        _isStrictMode = State(initialValue: s.isStrictMode)
        _selectedGradient = State(initialValue: s.themeGradient)
        _appSelectionData = State(initialValue: s.appSelectionData)
        _websiteDomains = State(initialValue: s.websiteDomains)

        #if os(iOS)
        if let data = s.appSelectionData,
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            _familyActivitySelection = State(initialValue: selection)
        }
        #endif
    }

    var body: some View {
        ZStack {
            // Dark background with gradient
            DesignSystem.Colors.background
                .ignoresSafeArea()

            // Gradient overlay matching selected color
            LinearGradient(
                colors: [
                    Color(hex: selectedGradient.primaryHex).opacity(0.15),
                    Color(hex: selectedGradient.secondaryHex).opacity(0.08),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
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
                            .overlay {
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                    .strokeBorder(selectedColor.opacity(0.3), lineWidth: 1)
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
                        Text("TIME")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)

                        #if os(macOS)
                        HStack(spacing: DesignSystem.Spacing.lg) {
                            MacInlineTimePicker(label: "Start", time: $startTime, accentColor: selectedColor)
                            MacInlineTimePicker(label: "End", time: $endTime, accentColor: selectedColor)
                        }
                        #else
                        HStack(spacing: DesignSystem.Spacing.md) {
                            timePickerCard(label: "Start", time: $startTime)
                            timePickerCard(label: "End", time: $endTime)
                        }
                        #endif
                    }

                    // App blocking section
                    appBlockingSection

                    // Website blocking section
                    websiteBlockingSection

                    // Strict mode toggle
                    strictModeRow

                    // Duration preview
                    durationPreview

                    // Delete button (only when editing)
                    if isEditing {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Schedule")
                            }
                            .foregroundStyle(DesignSystem.Colors.destructive)
                        }
                        .padding(.top, DesignSystem.Spacing.lg)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(isEditing ? "Edit Schedule" : "New Schedule")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if let onCancel = onCancel {
                        onCancel()
                    } else {
                        dismiss()
                    }
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveSchedule()
                }
                .fontWeight(.semibold)
                .foregroundStyle(selectedColor)
                .disabled(!isValid)
            }
        }
        #if os(iOS)
        .familyActivityPicker(
            isPresented: $showingAppPicker,
            selection: $familyActivitySelection
        )
        .onChange(of: familyActivitySelection) { _, newSelection in
            appSelectionData = try? JSONEncoder().encode(newSelection)
        }
        #endif
        .confirmationDialog(
            "Delete Schedule",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let schedule = existingSchedule {
                    scheduleManager.deleteSchedule(id: schedule.id)
                    if let onCancel = onCancel {
                        onCancel()
                    } else {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this schedule.")
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
                .tint(selectedColor)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
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

                    if !premiumManager.isPremium {
                        Text("PRO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background {
                                Capsule()
                                    .fill(selectedColor)
                            }
                    }
                }

                Text("Cannot be disabled during scheduled hours")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isStrictMode },
                set: { newValue in
                    if newValue {
                        // Trying to enable strict mode
                        if premiumManager.isPremium {
                            showingStrictModeWarning = true
                        } else {
                            showingPaywall = true
                        }
                    } else {
                        isStrictMode = false
                    }
                }
            ))
            .tint(selectedColor)
            .labelsHidden()
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .alert("Enable Strict Mode?", isPresented: $showingStrictModeWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Enable") {
                isStrictMode = true
            }
        } message: {
            Text("Once active, you won't be able to disable blocking or end the schedule early. This helps you stay committed to your focus goals.\n\nAre you sure you want to enable Strict Mode?")
        }
    }

    // MARK: - App Blocking Section

    private var appBlockingSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("BLOCK APPS")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Button {
                #if os(iOS)
                showingAppPicker = true
                #endif
            } label: {
                HStack {
                    Image(systemName: "app.badge")
                        .font(.system(size: 18))
                        .foregroundStyle(selectedColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Select Apps to Block")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        #if os(iOS)
                        let appCount = familyActivitySelection.applicationTokens.count
                        let categoryCount = familyActivitySelection.categoryTokens.count
                        if appCount > 0 || categoryCount > 0 {
                            Text("\(appCount) apps, \(categoryCount) categories selected")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(selectedColor)
                        } else {
                            Text("No apps selected")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }
                        #else
                        Text("Not available on macOS")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        #endif
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.backgroundCard)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Website Blocking Section

    private var websiteBlockingSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("BLOCK WEBSITES")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                // Add website input
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.textMuted)

                    TextField("e.g. google.com", text: $newWebsite)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .onSubmit {
                            addWebsite()
                        }

                    Button {
                        addWebsite()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(newWebsite.isEmpty ? DesignSystem.Colors.textMuted : selectedColor)
                    }
                    .disabled(newWebsite.isEmpty)
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.backgroundCard)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                }

                // Website list
                if !websiteDomains.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(websiteDomains, id: \.self) { domain in
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                // Favicon
                                AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=32")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    Image(systemName: "globe")
                                        .foregroundStyle(DesignSystem.Colors.textMuted)
                                }
                                .frame(width: 20, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                                Text(domain)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                                Spacer()

                                Button {
                                    withAnimation {
                                        websiteDomains.removeAll { $0 == domain }
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(DesignSystem.Colors.textMuted)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)

                            if domain != websiteDomains.last {
                                Divider()
                                    .background(DesignSystem.Colors.border)
                            }
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .fill(DesignSystem.Colors.backgroundCard)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                    }
                }
            }
        }
    }

    private func addWebsite() {
        let domain = newWebsite.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")

        guard !domain.isEmpty && !websiteDomains.contains(domain) else {
            newWebsite = ""
            return
        }

        withAnimation {
            websiteDomains.append(domain)
            newWebsite = ""
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
            themeGradient: selectedGradient,
            appSelectionData: appSelectionData,
            websiteDomains: websiteDomains
        )

        if isEditing {
            scheduleManager.updateSchedule(schedule)
        } else {
            scheduleManager.addSchedule(schedule)
        }

        if let onSave = onSave {
            onSave()
        } else {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        ScheduleEditorView()
    }
}
