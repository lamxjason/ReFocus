import SwiftUI

#if os(macOS)
import AppKit

struct MacAppsView: View {
    @StateObject private var appBlocker = MacAppBlocker.shared
    @State private var showingAppPicker = false
    @State private var searchText = ""

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
                // Add app bar
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "app.badge")
                        .foregroundStyle(DesignSystem.Colors.accent)

                    Text("Apps to block during focus sessions")
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
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background {
                            Capsule()
                                .fill(DesignSystem.Colors.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.backgroundCard)

                Divider()
                    .background(DesignSystem.Colors.border)

                // App list
                if appBlocker.blockedApps.isEmpty {
                    Spacer()
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "app.badge")
                            .font(.system(size: 48))
                            .foregroundStyle(DesignSystem.Colors.textMuted)

                        Text("No Blocked Apps")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        Text("Click 'Add App' to select apps to block during focus sessions.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(DesignSystem.Spacing.xl)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredApps) { app in
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    // App icon
                                    if let iconData = app.iconData,
                                       let nsImage = NSImage(data: iconData) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .frame(width: 32, height: 32)
                                            .cornerRadius(8)
                                    } else {
                                        Image(systemName: "app")
                                            .font(.title)
                                            .frame(width: 32, height: 32)
                                            .foregroundStyle(DesignSystem.Colors.accent)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.name)
                                            .font(DesignSystem.Typography.body)
                                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                                        Text(app.bundleId)
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    }

                                    Spacer()

                                    Button {
                                        appBlocker.removeBlockedApp(app)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(DesignSystem.Colors.destructive.opacity(0.8))
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(DesignSystem.Colors.backgroundCard)
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search apps")
        .navigationTitle("Apps")
        .toolbar {
            ToolbarItem {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Circle()
                        .fill(appBlocker.isEnabled ? DesignSystem.Colors.success : DesignSystem.Colors.textMuted)
                        .frame(width: 8, height: 8)

                    Text(appBlocker.isEnabled ? "Enabled" : "Disabled")
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            MacAppPickerSheet(onSelect: { app in
                appBlocker.addBlockedApp(app)
            })
        }
    }
}

struct MacAppPickerSheet: View {
    let onSelect: (BlockedMacApp) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var runningApps: [NSRunningApplication] = []
    @State private var searchText = ""

    var filteredApps: [NSRunningApplication] {
        let apps = runningApps.filter { app in
            app.bundleIdentifier != nil &&
            app.activationPolicy == .regular
        }

        if searchText.isEmpty {
            return apps
        }

        return apps.filter { app in
            app.localizedName?.localizedCaseInsensitiveContains(searchText) ?? false ||
            app.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false
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
                    .foregroundStyle(DesignSystem.Colors.accent)
                }
                .padding(DesignSystem.Spacing.md)

                Divider()
                    .background(DesignSystem.Colors.border)

                // Search
                TextField("Search apps", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(DesignSystem.Spacing.md)

                // App list
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredApps, id: \.processIdentifier) { app in
                            Button {
                                if let blockedApp = BlockedMacApp.fromRunningApplication(app) {
                                    onSelect(blockedApp)
                                }
                            } label: {
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 32, height: 32)
                                    }

                                    VStack(alignment: .leading) {
                                        Text(app.localizedName ?? "Unknown")
                                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        Text(app.bundleIdentifier ?? "")
                                            .font(.caption)
                                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(DesignSystem.Colors.accent)
                                }
                                .padding(DesignSystem.Spacing.sm)
                            }
                            .buttonStyle(.plain)
                            .background(DesignSystem.Colors.backgroundCard)
                        }
                    }
                    .padding(DesignSystem.Spacing.sm)
                }
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            runningApps = NSWorkspace.shared.runningApplications
        }
    }
}

#Preview {
    MacAppsView()
        .frame(width: 600, height: 400)
}
#endif
