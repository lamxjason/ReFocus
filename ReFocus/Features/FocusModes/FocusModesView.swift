import SwiftUI
#if os(iOS)
import FamilyControls
#endif

struct FocusModesView: View {
    @StateObject private var modeManager = FocusModeManager.shared
    @State private var showingAddMode = false
    @State private var editingMode: FocusMode?

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header
                    HStack {
                        Text("Focus Modes")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Spacer()

                        Button {
                            showingAddMode = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)

                    // Modes Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: DesignSystem.Spacing.md) {
                        ForEach(modeManager.modes) { mode in
                            FocusModeCard(
                                mode: mode,
                                isSelected: modeManager.selectedModeId == mode.id,
                                onSelect: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        modeManager.selectMode(mode)
                                    }
                                },
                                onEdit: {
                                    editingMode = mode
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                }
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
        }
        .sheet(isPresented: $showingAddMode) {
            FocusModeEditorView(mode: nil) { newMode in
                modeManager.addMode(newMode)
            }
        }
        .sheet(item: $editingMode) { mode in
            FocusModeEditorView(mode: mode) { updatedMode in
                modeManager.updateMode(updatedMode)
            } onDelete: {
                modeManager.deleteMode(mode)
            }
        }
    }
}

// MARK: - Focus Mode Card

struct FocusModeCard: View {
    let mode: FocusMode
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void

    private var modeColor: Color {
        mode.primaryColor
    }

    private var modeGradient: ThemeGradient {
        mode.effectiveGradient
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main card - tap to select
            Button {
                onSelect()
            } label: {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // Icon with mode color
                    ZStack {
                        Image(systemName: mode.icon)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(isSelected ? .white : modeColor)

                        // Strict mode lock badge
                        if mode.isStrictMode {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(isSelected ? .white : modeColor)
                                        .padding(3)
                                        .background {
                                            Circle()
                                                .fill(isSelected ? modeColor : modeColor.opacity(0.2))
                                        }
                                        .offset(x: 4, y: 4)
                                }
                            }
                        }
                    }
                    .frame(width: 52, height: 52)
                    .background {
                        Circle()
                            .fill(
                                isSelected
                                    ? LinearGradient(
                                        colors: [
                                            Color(hex: modeGradient.primaryHex),
                                            Color(hex: modeGradient.secondaryHex)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [
                                            Color(hex: modeGradient.primaryHex).opacity(0.15),
                                            Color(hex: modeGradient.secondaryHex).opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                    }

                    // Name
                    Text(mode.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    // Duration
                    Text(mode.durationFormatted)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .padding(.horizontal, DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            // Action buttons row
            HStack(spacing: 0) {
                Button {
                    onEdit()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                        Text("Edit")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(modeColor.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(modeColor.opacity(0.3))
                    .frame(width: 1, height: 16)

                Button {
                    FocusModeManager.shared.duplicateMode(mode)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("Copy")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(modeColor.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
            .background(Color(hex: modeGradient.primaryHex).opacity(0.1))
        }
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: isSelected
                            ? [
                                Color(hex: modeGradient.primaryHex).opacity(0.6),
                                Color(hex: modeGradient.secondaryHex).opacity(0.4),
                                Color(hex: modeGradient.tertiaryHex).opacity(0.25)
                            ]
                            : [
                                Color(hex: modeGradient.primaryHex).opacity(0.25),
                                Color(hex: modeGradient.secondaryHex).opacity(0.12),
                                AppTheme.cardBackground
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: isSelected
                            ? [modeColor, modeColor.opacity(0.7)]
                            : [modeColor.opacity(0.4), modeColor.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Focus Mode Editor

struct FocusModeEditorView: View {
    @Environment(\.dismiss) var dismiss

    let existingMode: FocusMode?
    let onSave: (FocusMode) -> Void
    var onDelete: (() -> Void)?

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedGradient: ThemeGradient
    @State private var hours: Int
    @State private var minutes: Int
    @State private var isStrictMode: Bool
    @State private var websiteDomains: [String]
    @State private var showingDeleteConfirm = false
    @State private var showingAppPicker = false
    @State private var showingAddWebsite = false
    @State private var newWebsite: String = ""

    #if os(iOS)
    @State private var appSelection: FamilyActivitySelection
    #endif

    init(mode: FocusMode?, onSave: @escaping (FocusMode) -> Void, onDelete: (() -> Void)? = nil) {
        self.existingMode = mode
        self.onSave = onSave
        self.onDelete = onDelete

        _name = State(initialValue: mode?.name ?? "")
        _selectedIcon = State(initialValue: mode?.icon ?? "timer")
        _selectedGradient = State(initialValue: mode?.effectiveGradient ?? .violet)
        _hours = State(initialValue: mode != nil ? Int(mode!.duration) / 3600 : 0)
        _minutes = State(initialValue: mode != nil ? (Int(mode!.duration) % 3600) / 60 : 25)
        _isStrictMode = State(initialValue: mode?.isStrictMode ?? false)
        _websiteDomains = State(initialValue: mode?.websiteDomains ?? [])

        #if os(iOS)
        _appSelection = State(initialValue: mode?.appSelection ?? FamilyActivitySelection())
        #endif
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (hours > 0 || minutes > 0)
    }

    private var modeColor: Color {
        Color(hex: selectedGradient.primaryHex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Preview
                        previewCard

                        // Name
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("NAME")
                                .sectionHeader()

                            TextField("Mode name", text: $name)
                                .textFieldStyle(.plain)
                                .font(DesignSystem.Typography.body)
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .padding(DesignSystem.Spacing.md)
                                .background {
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                        .fill(DesignSystem.Colors.backgroundCard)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                        .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                                }
                        }

                        // Duration
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("DURATION")
                                .sectionHeader()

                            HStack(spacing: DesignSystem.Spacing.lg) {
                                durationPicker(label: "Hours", value: $hours, range: 0..<24)
                                durationPicker(label: "Minutes", value: $minutes, range: 0..<60)
                            }
                        }

                        // Icon
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("ICON")
                                .sectionHeader()

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: DesignSystem.Spacing.sm) {
                                ForEach(FocusModeIcon.allCases, id: \.rawValue) { icon in
                                    iconButton(icon: icon.rawValue)
                                }
                            }
                        }

                        // Color
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("COLOR")
                                .sectionHeader()

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach(ThemeGradient.allCases, id: \.self) { gradient in
                                        gradientButton(gradient)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }

                        // Strict Mode
                        Toggle(isOn: $isStrictMode) {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(modeColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Strict Mode")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                                    Text("Can't end session early")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                }
                            }
                        }
                        .tint(modeColor)
                        .padding(DesignSystem.Spacing.md)
                        .background {
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                .fill(DesignSystem.Colors.backgroundCard)
                        }

                        // Apps to block (iOS only)
                        #if os(iOS)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("BLOCK APPS")
                                .sectionHeader()

                            Button {
                                showingAppPicker = true
                            } label: {
                                HStack {
                                    // Show app icons if any selected
                                    if !appSelection.applicationTokens.isEmpty {
                                        HStack(spacing: -6) {
                                            ForEach(Array(appSelection.applicationTokens.prefix(4).enumerated()), id: \.offset) { _, token in
                                                Label(token)
                                                    .labelStyle(.iconOnly)
                                                    .scaleEffect(0.55)
                                                    .frame(width: 28, height: 28)
                                                    .clipShape(Circle())
                                            }
                                            if appSelection.applicationTokens.count > 4 {
                                                Text("+\(appSelection.applicationTokens.count - 4)")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                                    .frame(width: 28, height: 28)
                                                    .background {
                                                        Circle()
                                                            .fill(DesignSystem.Colors.backgroundElevated)
                                                    }
                                            }
                                        }
                                    } else {
                                        Image(systemName: "app.badge")
                                            .font(.system(size: 18))
                                            .foregroundStyle(modeColor)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Select Apps")
                                            .font(DesignSystem.Typography.bodyMedium)
                                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                                        let appCount = appSelection.applicationTokens.count + appSelection.categoryTokens.count
                                        Text(appCount > 0 ? "\(appCount) app\(appCount == 1 ? "" : "s") selected" : "No apps selected")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background {
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                        .fill(DesignSystem.Colors.backgroundCard)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        #endif

                        // Websites to block
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text("BLOCK WEBSITES")
                                    .sectionHeader()

                                Spacer()

                                Button {
                                    showingAddWebsite = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(modeColor)
                                }
                            }

                            if websiteDomains.isEmpty {
                                Text("No websites added")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(DesignSystem.Spacing.lg)
                                    .background {
                                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                            .fill(DesignSystem.Colors.backgroundCard)
                                    }
                            } else {
                                VStack(spacing: 1) {
                                    ForEach(websiteDomains, id: \.self) { domain in
                                        HStack {
                                            WebsiteFavicon(domain: domain, size: 24)

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
                                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                            }
                                        }
                                        .padding(DesignSystem.Spacing.md)
                                        .background(DesignSystem.Colors.backgroundCard)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                            }
                        }

                        // Delete button (only for existing modes)
                        if existingMode != nil, onDelete != nil {
                            Button(role: .destructive) {
                                showingDeleteConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Mode")
                                }
                                .foregroundStyle(DesignSystem.Colors.destructive)
                            }
                            .padding(.top, DesignSystem.Spacing.md)
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle(existingMode == nil ? "New Mode" : "Edit Mode")
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
                        saveMode()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(isValid ? modeColor : DesignSystem.Colors.textMuted)
                    .disabled(!isValid)
                }
            }
            .confirmationDialog("Delete this mode?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(DesignSystem.Colors.backgroundElevated)
        .familyActivityPicker(isPresented: $showingAppPicker, selection: $appSelection)
        #endif
        .alert("Add Website", isPresented: $showingAddWebsite) {
            TextField("example.com", text: $newWebsite)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Add") {
                addWebsite()
            }
            Button("Cancel", role: .cancel) {
                newWebsite = ""
            }
        } message: {
            Text("Enter the domain to block (e.g., twitter.com)")
        }
    }

    private func addWebsite() {
        let domain = newWebsite.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")

        if !domain.isEmpty && !websiteDomains.contains(domain) {
            withAnimation {
                websiteDomains.append(domain)
            }
        }
        newWebsite = ""
    }

    private var previewCard: some View {
        ZStack {
            // Dynamic gradient based on selected gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: selectedGradient.primaryHex),
                            Color(hex: selectedGradient.secondaryHex).opacity(0.8),
                            Color(hex: selectedGradient.tertiaryHex).opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white)

                    if isStrictMode {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background {
                                        Circle()
                                            .fill(.white.opacity(0.3))
                                    }
                                    .offset(x: 4, y: 4)
                            }
                        }
                    }
                }
                .frame(width: 64, height: 64)
                .background {
                    Circle()
                        .fill(.white.opacity(0.2))
                }

                Text(name.isEmpty ? "Mode Name" : name)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.white)

                Text(formatDuration())
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    private func durationPicker(label: String, value: Binding<Int>, range: Range<Int>) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Picker(label, selection: value) {
                ForEach(range, id: \.self) { num in
                    Text("\(num)").tag(num)
                }
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #else
            .pickerStyle(.menu)
            #endif
            .frame(height: 100)

            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundCard)
        }
    }

    private func iconButton(icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                selectedIcon = icon
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(selectedIcon == icon ? .white : DesignSystem.Colors.textSecondary)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(selectedIcon == icon ? Color(hex: selectedGradient.primaryHex) : DesignSystem.Colors.backgroundCard)
                }
                .overlay {
                    Circle()
                        .strokeBorder(selectedIcon == icon ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func gradientButton(_ gradient: ThemeGradient) -> some View {
        let isSelected = selectedGradient == gradient

        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
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

    private func formatDuration() -> String {
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private func saveMode() {
        var mode = existingMode ?? FocusMode(name: name)
        mode.name = name.trimmingCharacters(in: .whitespaces)
        mode.icon = selectedIcon
        mode.color = selectedGradient.primaryHex // Keep legacy color in sync
        mode.themeGradient = selectedGradient
        mode.duration = TimeInterval(hours * 3600 + minutes * 60)
        mode.isStrictMode = isStrictMode
        mode.websiteDomains = websiteDomains

        #if os(iOS)
        mode.setAppSelection(appSelection)
        #endif

        onSave(mode)
        dismiss()
    }
}

#Preview {
    FocusModesView()
}
