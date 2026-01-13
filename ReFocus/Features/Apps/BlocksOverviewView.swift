import SwiftUI

#if os(iOS)
import FamilyControls
#endif

struct BlocksOverviewView: View {
    @EnvironmentObject var websiteSyncManager: WebsiteSyncManager
    @EnvironmentObject var blockEnforcementManager: BlockEnforcementManager

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                // Status badge
                statusBadge
                    .padding(.top, DesignSystem.Spacing.lg)

                // Cards
                VStack(spacing: DesignSystem.Spacing.md) {
                    #if os(iOS)
                    NavigationLink {
                        AppSelectionView()
                    } label: {
                        BlockCard(
                            icon: "app.badge",
                            title: "Apps",
                            count: blockEnforcementManager.localAppSelection.appCount,
                            subtitle: "This device only"
                        )
                    }
                    .buttonStyle(.plain)
                    #endif

                    NavigationLink {
                        WebsiteListView()
                    } label: {
                        BlockCard(
                            icon: "globe",
                            title: "Websites",
                            count: websiteSyncManager.blockedWebsites.count,
                            subtitle: "Synced across devices",
                            isSynced: websiteSyncManager.isConnected
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Spacer()
            }
        }
        .navigationTitle("Blocks")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private var statusBadge: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(blockEnforcementManager.isEnforcing
                      ? DesignSystem.Colors.success
                      : DesignSystem.Colors.textMuted)
                .frame(width: 8, height: 8)

            Text(blockEnforcementManager.isEnforcing ? "Protection Active" : "Protection Inactive")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(blockEnforcementManager.isEnforcing
                                 ? DesignSystem.Colors.success
                                 : DesignSystem.Colors.textSecondary)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background {
            Capsule()
                .fill(blockEnforcementManager.isEnforcing
                      ? DesignSystem.Colors.success.opacity(0.15)
                      : DesignSystem.Colors.backgroundCard)
        }
    }
}

// MARK: - Block Card

struct BlockCard: View {
    let icon: String
    let title: String
    let count: Int
    var subtitle: String? = nil
    var isSynced: Bool = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(DesignSystem.Colors.accentSoft)
                }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text("\(count) blocked")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    if let subtitle {
                        Text("•")
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                        Text(subtitle)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    if isSynced {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                            .foregroundStyle(DesignSystem.Colors.success)
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textMuted)
        }
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
}

// MARK: - iOS App Selection

#if os(iOS)
struct AppSelectionView: View {
    @EnvironmentObject var blockEnforcementManager: BlockEnforcementManager

    @State private var showingPicker = false
    @State private var pickerSelection = FamilyActivitySelection()
    @State private var isRequestingAuth = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                // Authorization status
                if !blockEnforcementManager.isScreenTimeAuthorized {
                    authorizationPrompt
                } else {
                    // Stats
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        StatPill(value: blockEnforcementManager.localAppSelection.appCount, label: "Apps")
                        StatPill(value: blockEnforcementManager.localAppSelection.categoryCount, label: "Categories")
                        StatPill(value: blockEnforcementManager.localAppSelection.websiteCount, label: "Sites")
                    }
                    .padding(.top, DesignSystem.Spacing.lg)

                    // Select button
                    Button {
                        pickerSelection = blockEnforcementManager.localAppSelection.selection
                        showingPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.app.fill")
                            Text("Select Apps to Block")
                        }
                    }
                    .buttonStyle(.primary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    // Info
                    Text("Selected apps and categories will be blocked during focus sessions. This selection is stored locally on this device.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                }

                Spacer()
            }
        }
        .navigationTitle("Apps")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        .familyActivityPicker(
            isPresented: $showingPicker,
            selection: $pickerSelection
        )
        .onChange(of: pickerSelection) { _, newValue in
            let selection = LocalAppSelection(selection: newValue, lastModified: Date())
            blockEnforcementManager.updateAppSelection(selection)
        }
        .onAppear {
            blockEnforcementManager.checkScreenTimeAuthorization()
        }
    }

    private var authorizationPrompt: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "hourglass.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.accent)
                .padding(.top, DesignSystem.Spacing.xxl)

            Text("Screen Time Required")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("ReFocus needs Screen Time permission to block apps during focus sessions.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            Button {
                requestAuthorization()
            } label: {
                if isRequestingAuth {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Enable Screen Time")
                    }
                }
            }
            .buttonStyle(.primary)
            .disabled(isRequestingAuth)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
        }
    }

    private func requestAuthorization() {
        isRequestingAuth = true
        Task {
            do {
                try await blockEnforcementManager.requestScreenTimeAuthorization()
            } catch {
                // Authorization denied or failed - user can try again
                print("Screen Time authorization failed: \(error)")
            }
            isRequestingAuth = false
        }
    }
}

struct StatPill: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text("\(value)")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                .fill(DesignSystem.Colors.backgroundCard)
        }
    }
}
#endif

#Preview {
    NavigationStack {
        BlocksOverviewView()
    }
    .environmentObject(WebsiteSyncManager.shared)
    .environmentObject(BlockEnforcementManager.shared)
}
