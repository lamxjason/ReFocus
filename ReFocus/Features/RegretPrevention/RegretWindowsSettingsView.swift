import SwiftUI

/// Settings view for configuring Regret Prevention windows
struct RegretWindowsSettingsView: View {
    @StateObject private var regretManager = RegretPreventionManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingPaywall = false
    @State private var showingAddCustomWindow = false
    @State private var editingWindow: RegretWindow?

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Enable toggle
                        enableSection

                        if regretManager.config.isEnabled {
                            // Current status
                            statusSection

                            // Windows list
                            windowsSection

                            // Add custom window
                            addWindowSection
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Regret Prevention")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PremiumPaywallView()
            }
            .sheet(isPresented: $showingAddCustomWindow) {
                CustomWindowEditorView(
                    window: nil,
                    onSave: { window in
                        regretManager.config.addWindow(window)
                    }
                )
            }
            .sheet(item: $editingWindow) { window in
                CustomWindowEditorView(
                    window: window,
                    onSave: { updatedWindow in
                        regretManager.config.updateWindow(updatedWindow)
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Enable Section

    private var enableSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            ZStack(alignment: .topTrailing) {
                // Gradient card
                RoundedRectangle(cornerRadius: 20)
                    .fill(regretManager.config.isEnabled ? RichGradients.forest : RichGradients.midnight)
                    .frame(height: 100)

                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: regretManager.config.isEnabled ? "shield.checkered" : "shield")
                                .font(.system(size: 18))

                            Text("Regret Prevention")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)

                        Text(regretManager.config.isEnabled ? "Protection windows active" : "Auto-block during vulnerable hours")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { regretManager.config.isEnabled },
                        set: { newValue in
                            if newValue && !premiumManager.isPremium {
                                showingPaywall = true
                            } else {
                                withAnimation(.spring(response: 0.3)) {
                                    regretManager.config.isEnabled = newValue
                                    regretManager.checkProtection()
                                }
                            }
                        }
                    ))
                    .tint(.white)
                    .labelsHidden()
                }
                .padding(DesignSystem.Spacing.lg)

                // PRO badge
                if !premiumManager.isPremium {
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(Color(hex: "7DCEA0"))
                        }
                        .padding(12)
                }
            }

            Text("Blocking activates automatically during configured time windows to protect you from regretful browsing.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("STATUS")
                .sectionHeader()

            HStack(spacing: DesignSystem.Spacing.md) {
                // Status icon with gradient when active
                ZStack {
                    if regretManager.isProtectionActive {
                        Circle()
                            .fill(RichGradients.forest)
                            .frame(width: 44, height: 44)
                    } else {
                        Circle()
                            .fill(DesignSystem.Colors.backgroundElevated)
                            .frame(width: 44, height: 44)
                    }

                    Image(systemName: regretManager.isProtectionActive ? "shield.checkered" : "shield")
                        .font(.system(size: 20))
                        .foregroundStyle(regretManager.isProtectionActive ? .white : DesignSystem.Colors.textMuted)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(regretManager.isProtectionActive ? "Protection Active" : "Not Currently Active")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text(regretManager.statusMessage)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.backgroundCard)
            }
        }
    }

    // MARK: - Windows Section

    private var windowsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("PROTECTION WINDOWS")
                .sectionHeader()

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(regretManager.config.windows) { window in
                    windowRow(window)
                }
            }
        }
    }

    private func windowRow(_ window: RegretWindow) -> some View {
        let isActive = window.isCurrentlyActive && window.isEnabled

        return HStack(spacing: DesignSystem.Spacing.md) {
            // Icon with gradient when active
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(windowGradient(for: window.type))
                        .frame(width: 40, height: 40)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(window.isEnabled ? DesignSystem.Colors.backgroundElevated : DesignSystem.Colors.backgroundCard)
                        .frame(width: 40, height: 40)
                }

                Image(systemName: window.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isActive ? .white : (window.isEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.textMuted))
            }

            // Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(window.name)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(window.isEnabled ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)

                    if isActive {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background {
                                Capsule()
                                    .fill(Color(hex: "2D5A3D"))
                            }
                    }
                }

                Text(windowSubtitle(for: window))
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            Spacer()

            // Actions
            if window.type == .custom {
                Button {
                    editingWindow = window
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
            }

            Toggle("", isOn: Binding(
                get: { window.isEnabled },
                set: { _ in regretManager.toggleWindow(id: window.id) }
            ))
            .tint(DesignSystem.Colors.accent)
            .labelsHidden()
        }
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(isActive ? windowBackgroundColor(for: window.type) : DesignSystem.Colors.backgroundCard)
        }
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .strokeBorder(Color(hex: "2D5A3D").opacity(0.5), lineWidth: 1)
            }
        }
    }

    private func windowGradient(for type: RegretWindowType) -> LinearGradient {
        switch type {
        case .lateNight:
            return RichGradients.midnight
        case .postSession:
            return RichGradients.twilight
        case .custom:
            return RichGradients.ocean
        }
    }

    private func windowBackgroundColor(for type: RegretWindowType) -> Color {
        switch type {
        case .lateNight:
            return Color(hex: "1A2744").opacity(0.4)
        case .postSession:
            return Color(hex: "2D5A3D").opacity(0.2)
        case .custom:
            return Color(hex: "1A5276").opacity(0.3)
        }
    }

    private func windowSubtitle(for window: RegretWindow) -> String {
        switch window.type {
        case .lateNight:
            if let start = window.startTime, let end = window.endTime {
                return "\(start.displayString) – \(end.displayString)"
            }
            return "11:00 PM – 6:00 AM"

        case .postSession:
            if let duration = window.durationMinutes {
                return "\(duration) minutes after each session"
            }
            return "30 minutes after each session"

        case .custom:
            if let start = window.startTime, let end = window.endTime {
                return "\(start.displayString) – \(end.displayString)"
            }
            return "Custom time range"
        }
    }

    // MARK: - Add Window Section

    private var addWindowSection: some View {
        Button {
            showingAddCustomWindow = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))

                Text("Add Custom Window")
                    .font(DesignSystem.Typography.bodyMedium)

                Spacer()
            }
            .foregroundStyle(DesignSystem.Colors.accent)
            .padding(DesignSystem.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.accentSoft)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Window Editor

struct CustomWindowEditorView: View {
    let window: RegretWindow?
    let onSave: (RegretWindow) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var startHour: Int = 9
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 17
    @State private var endMinute: Int = 0
    @State private var message: String = ""

    private var isEditing: Bool { window != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Name
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("NAME")
                                .sectionHeader()

                            TextField("e.g., Morning Focus", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .font(DesignSystem.Typography.body)
                        }

                        // Time Range
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("TIME RANGE")
                                .sectionHeader()

                            #if os(iOS)
                            HStack(spacing: DesignSystem.Spacing.lg) {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                                    Text("Start")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                                    HStack(spacing: DesignSystem.Spacing.xs) {
                                        Picker("Hour", selection: $startHour) {
                                            ForEach(0..<24, id: \.self) { hour in
                                                Text(String(format: "%02d", hour)).tag(hour)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(width: 60, height: 100)
                                        .clipped()

                                        Text(":")

                                        Picker("Minute", selection: $startMinute) {
                                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                                Text(String(format: "%02d", minute)).tag(minute)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(width: 60, height: 100)
                                        .clipped()
                                    }
                                }

                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                                    Text("End")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                                    HStack(spacing: DesignSystem.Spacing.xs) {
                                        Picker("Hour", selection: $endHour) {
                                            ForEach(0..<24, id: \.self) { hour in
                                                Text(String(format: "%02d", hour)).tag(hour)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(width: 60, height: 100)
                                        .clipped()

                                        Text(":")

                                        Picker("Minute", selection: $endMinute) {
                                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                                Text(String(format: "%02d", minute)).tag(minute)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(width: 60, height: 100)
                                        .clipped()
                                    }
                                }
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background {
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                    .fill(DesignSystem.Colors.backgroundCard)
                            }
                            #else
                            HStack(spacing: DesignSystem.Spacing.lg) {
                                MacInlineTimeOfDayPicker(
                                    label: "Start",
                                    hour: $startHour,
                                    minute: $startMinute,
                                    accentColor: DesignSystem.Colors.accent,
                                    minuteStep: 15
                                )

                                MacInlineTimeOfDayPicker(
                                    label: "End",
                                    hour: $endHour,
                                    minute: $endMinute,
                                    accentColor: DesignSystem.Colors.accent,
                                    minuteStep: 15
                                )
                            }
                            #endif
                        }

                        // Message
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("MESSAGE (OPTIONAL)")
                                .sectionHeader()

                            TextField("Custom protection message...", text: $message, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .font(DesignSystem.Typography.body)
                                .lineLimit(3...6)
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle(isEditing ? "Edit Window" : "New Window")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWindow()
                    }
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let window = window {
                    name = window.name
                    startHour = window.startTime?.hour ?? 9
                    startMinute = window.startTime?.minute ?? 0
                    endHour = window.endTime?.hour ?? 17
                    endMinute = window.endTime?.minute ?? 0
                    message = window.message
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveWindow() {
        var newWindow: RegretWindow

        if let existing = window {
            newWindow = existing
            newWindow.name = name
            newWindow.startTime = TimeComponents(hour: startHour, minute: startMinute)
            newWindow.endTime = TimeComponents(hour: endHour, minute: endMinute)
            newWindow.message = message.isEmpty ? RegretWindowType.custom.defaultMessage : message
        } else {
            newWindow = RegretWindow.custom(
                name: name,
                startTime: TimeComponents(hour: startHour, minute: startMinute),
                endTime: TimeComponents(hour: endHour, minute: endMinute),
                message: message.isEmpty ? nil : message
            )
        }

        onSave(newWindow)
        dismiss()
    }
}

#Preview {
    RegretWindowsSettingsView()
}
