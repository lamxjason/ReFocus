import SwiftUI

#if os(macOS)
import AppKit

struct MacAppsView: View {
    @StateObject private var appBlocker = MacAppBlocker.shared
    @State private var showingAppPicker = false
    @State private var searchText = ""
    @State private var recentlyAdded: String?

    var filteredApps: [BlockedMacApp] {
        if searchText.isEmpty {
            return appBlocker.blockedApps
        }
        return appBlocker.blockedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Status notice
                appBlockingNotice
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)

                // Header with add button
                headerSection
                    .padding(DesignSystem.Spacing.lg)

                // App list
                if appBlocker.blockedApps.isEmpty {
                    emptyState
                } else {
                    appList
                }
            }
        }
        .navigationTitle("Apps")
        .toolbar {
            ToolbarItem {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Circle()
                        .fill(appBlocker.isEnabled ? DesignSystem.Colors.success : DesignSystem.Colors.textMuted)
                        .frame(width: 8, height: 8)

                    Text("\(appBlocker.blockedApps.count) blocked")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            MacAppPickerSheet { app in
                addApp(app)
            }
        }
    }

    // MARK: - App Blocking Notice

    private var appBlockingNotice: some View {
        let hasApps = !appBlocker.blockedApps.isEmpty
        let isActive = appBlocker.isEnabled

        return HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: isActive ? "checkmark.shield.fill" : (hasApps ? "app.badge.checkmark" : "info.circle"))
                .font(.system(size: 16))
                .foregroundStyle(isActive ? DesignSystem.Colors.success : (hasApps ? DesignSystem.Colors.accent : DesignSystem.Colors.textMuted))

            VStack(alignment: .leading, spacing: 2) {
                Text(isActive ? "Blocking active" : (hasApps ? "Ready to block" : "No apps selected"))
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(isActive
                     ? "Selected apps will be terminated if launched"
                     : (hasApps ? "Apps will be blocked when you start a focus session" : "Add apps below to block during focus sessions"))
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(isActive
                      ? DesignSystem.Colors.success.opacity(0.1)
                      : (hasApps ? DesignSystem.Colors.accent.opacity(0.08) : DesignSystem.Colors.backgroundCard))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(
                    isActive
                        ? DesignSystem.Colors.success.opacity(0.3)
                        : (hasApps ? DesignSystem.Colors.accent.opacity(0.2) : DesignSystem.Colors.border),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "app.badge")
                .font(.system(size: 16))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 24)

            Text("Select apps to block during focus sessions")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Spacer()

            Button {
                showingAppPicker = true
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "plus")
                    Text("Add App")
                }
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background {
                    Capsule()
                        .fill(DesignSystem.Colors.accent)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Spacer()

            Image(systemName: "app.badge")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textMuted)

            Text("No Blocked Apps")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Text("Click 'Add App' to select apps to block during focus sessions.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()
        }
    }

    // MARK: - App List

    private var appList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(filteredApps) { app in
                    MacAppRowView(
                        app: app,
                        isNew: recentlyAdded == app.bundleId
                    ) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            appBlocker.removeBlockedApp(app)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appBlocker.blockedApps.count)
        }
    }

    // MARK: - Actions

    private func addApp(_ app: BlockedMacApp) {
        // Check for duplicates
        guard !appBlocker.blockedApps.contains(where: { $0.bundleId == app.bundleId }) else {
            return
        }

        appBlocker.addBlockedApp(app)

        // Trigger animation for newly added item
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            recentlyAdded = app.bundleId
        }

        // Clear the "new" highlight after a moment
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation {
                recentlyAdded = nil
            }
        }
    }
}

// MARK: - App Row View

struct MacAppRowView: View {
    let app: BlockedMacApp
    var isNew: Bool = false
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // App icon
            if let iconData = app.iconData,
               let nsImage = NSImage(data: iconData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        if isNew {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(DesignSystem.Colors.accent, lineWidth: 2)
                        }
                    }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.Colors.backgroundElevated)
                    Image(systemName: "app")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
                .frame(width: 40, height: 40)
                .overlay {
                    if isNew {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(DesignSystem.Colors.accent, lineWidth: 2)
                    }
                }
            }

            // App info
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(app.bundleId)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            // Delete button
            Button {
                showingDeleteConfirm = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isHovered ? DesignSystem.Colors.destructive : DesignSystem.Colors.textMuted)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(isNew ? DesignSystem.Colors.accent.opacity(0.1) : DesignSystem.Colors.backgroundCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(
                    isNew ? DesignSystem.Colors.accent : (isHovered ? DesignSystem.Colors.border : Color.clear),
                    lineWidth: isNew ? 2 : 1
                )
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .confirmationDialog("Remove \(app.name)?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - App Picker Sheet

struct MacAppPickerSheet: View {
    let onSelect: (BlockedMacApp) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var installedApps: [AppInfo] = []
    @State private var searchText = ""
    @State private var isLoading = true

    struct AppInfo: Identifiable {
        let id = UUID()
        let name: String
        let bundleId: String
        let icon: NSImage?
        let path: URL
    }

    var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return installedApps
        }
        return installedApps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText) ||
            app.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Select App to Block")
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignSystem.Colors.accent)
                }
                .padding(DesignSystem.Spacing.lg)

                Divider()
                    .background(DesignSystem.Colors.border)

                // Search
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(DesignSystem.Colors.textMuted)

                    TextField("Search apps", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.body)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .padding(DesignSystem.Spacing.lg)

                // App list
                if isLoading {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                    Text("Loading apps...")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .padding(.top, DesignSystem.Spacing.md)
                    Spacer()
                } else if filteredApps.isEmpty {
                    Spacer()
                    Text("No apps found")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.xs) {
                            ForEach(filteredApps) { app in
                                AppPickerRowView(app: app) {
                                    selectApp(app)
                                }
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
        .task {
            await loadInstalledApps()
        }
    }

    private func loadInstalledApps() async {
        let apps = await Task.detached {
            let applicationsURL = URL(fileURLWithPath: "/Applications")
            let fileManager = FileManager.default

            guard let contents = try? fileManager.contentsOfDirectory(
                at: applicationsURL,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles]
            ) else {
                return [AppInfo]()
            }

            var apps: [AppInfo] = []

            for url in contents where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let bundleId = bundle.bundleIdentifier else {
                    continue
                }

                let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent

                let icon = NSWorkspace.shared.icon(forFile: url.path)

                apps.append(AppInfo(
                    name: name,
                    bundleId: bundleId,
                    icon: icon,
                    path: url
                ))
            }

            return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value

        await MainActor.run {
            installedApps = apps
            isLoading = false
        }
    }

    private func selectApp(_ app: AppInfo) {
        var iconData: Data?
        if let icon = app.icon {
            iconData = icon.tiffRepresentation
        }

        let blockedApp = BlockedMacApp(
            bundleId: app.bundleId,
            name: app.name,
            iconData: iconData
        )
        onSelect(blockedApp)
    }
}

// MARK: - App Picker Row

struct AppPickerRowView: View {
    let app: MacAppPickerSheet.AppInfo
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.Colors.backgroundElevated)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "app")
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                        }
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text(app.bundleId)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .opacity(isHovered ? 1 : 0.6)
            }
            .padding(DesignSystem.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isHovered ? DesignSystem.Colors.backgroundCard : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    MacAppsView()
        .frame(width: 600, height: 500)
}
#endif
