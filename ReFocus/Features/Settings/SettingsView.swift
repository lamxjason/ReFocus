import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var blockEnforcementManager: BlockEnforcementManager
    @StateObject private var premiumManager = PremiumManager.shared
    @StateObject private var hardModeManager = HardModeManager.shared
    @StateObject private var regretManager = RegretPreventionManager.shared
    @StateObject private var localPreferences = LocalPreferencesManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    #if os(iOS)
    @StateObject private var contentBlocker = SafariContentBlockerManager.shared
    @StateObject private var systemFocusManager = SystemFocusManager.shared
    #endif

    @State private var showingPaywall = false
    @State private var showingHardModeSettings = false
    @State private var showingRegretPreventionSettings = false
    @State private var isSigningIn = false

    // Consistent accent color throughout settings
    private let accent = DesignSystem.Colors.accent

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Premium Section
                    premiumSection
                        .padding(.top, DesignSystem.Spacing.md)

                    // Features Section
                    featuresSection

                    // Account Section
                    accountSection

                    // Experience Section
                    experienceSection

                    // Social Section
                    socialSection

                    // Notifications Section
                    notificationsSection

                    #if os(iOS)
                    // System Focus Integration
                    focusSyncSection

                    // Blocking Settings (iOS)
                    blockingSection
                    #endif

                    #if os(macOS)
                    // Network Extension (macOS)
                    networkExtensionSection
                    #endif

                    // About
                    aboutSection
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
        .sheet(isPresented: $showingHardModeSettings) {
            HardModeSettingsView()
        }
        .sheet(isPresented: $showingRegretPreventionSettings) {
            RegretWindowsSettingsView()
        }
    }

    // MARK: - Premium Section

    private var premiumSection: some View {
        Group {
            if premiumManager.isPremium {
                // Premium active - subtle confirmation
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.proBadgeBackground)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Premium Active")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("All features unlocked")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.cardBackground)
                }
            } else {
                // Upgrade prompt with premium gradient
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        // Premium icon with glow
                        ZStack {
                            Circle()
                                .fill(AppTheme.proBadgeBackground.opacity(0.2))
                                .frame(width: 40, height: 40)

                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(AppTheme.proBadgeBackground)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Upgrade to Premium")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                ProBadge()
                            }
                            Text("Session lock, regret prevention & more")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background {
                        // Premium gradient background
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "2D5A3D"),  // Forest green
                                        Color(hex: "4A8C5C"),  // Lighter green
                                        Color(hex: "7DCEA0").opacity(0.8)  // Mint accent
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("FOCUS FEATURES")
                .sectionHeader()

            VStack(spacing: DesignSystem.Spacing.xs) {
                // Session Lock
                SettingRow(
                    icon: premiumManager.isStrictModeEnabled ? "lock.fill" : "lock.open",
                    iconColor: accent,
                    title: "Session Lock",
                    subtitle: premiumManager.isStrictModeEnabled
                        ? "\(hardModeManager.config.minimumCommitmentMinutes)min commitment"
                        : "Lock focus sessions",
                    showProBadge: !premiumManager.isPremium
                ) {
                    if premiumManager.isPremium {
                        Toggle("", isOn: Binding(
                            get: { premiumManager.isStrictModeEnabled },
                            set: { _ in premiumManager.toggleStrictMode() }
                        ))
                        .tint(accent)
                        .labelsHidden()
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                .onTapGesture {
                    if premiumManager.isPremium {
                        showingHardModeSettings = true
                    } else {
                        showingPaywall = true
                    }
                }

                // Regret Prevention
                SettingRow(
                    icon: regretManager.config.isEnabled ? "shield.checkered" : "shield",
                    iconColor: accent,
                    title: "Regret Prevention",
                    subtitle: regretManager.config.isEnabled
                        ? "\(regretManager.config.enabledWindows.count) protection window\(regretManager.config.enabledWindows.count == 1 ? "" : "s")"
                        : "Auto-block during vulnerable hours",
                    showProBadge: !premiumManager.isPremium
                ) {
                    if premiumManager.isPremium {
                        Toggle("", isOn: Binding(
                            get: { regretManager.config.isEnabled },
                            set: { newValue in
                                regretManager.config.isEnabled = newValue
                                regretManager.checkProtection()
                            }
                        ))
                        .tint(accent)
                        .labelsHidden()
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                .onTapGesture {
                    if premiumManager.isPremium {
                        showingRegretPreventionSettings = true
                    } else {
                        showingPaywall = true
                    }
                }
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("SYNC")
                    .sectionHeader()

                if !premiumManager.isPremium {
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(accent)
                        }
                }
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: supabaseManager.isAuthenticated ? "checkmark.circle.fill" : "icloud")
                    .font(.system(size: 20))
                    .foregroundStyle(supabaseManager.isAuthenticated ? AppTheme.success : AppTheme.textMuted)

                VStack(alignment: .leading, spacing: 2) {
                    Text(supabaseManager.isAuthenticated ? "Sync Enabled" : "Local Only")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(supabaseManager.isAuthenticated ? "Data syncs across devices" : "Data stored on this device")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                if !supabaseManager.isAuthenticated {
                    if isSigningIn {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Enable") {
                            if premiumManager.isPremium {
                                enableSync()
                            } else {
                                showingPaywall = true
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(accent)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.cardBackground)
            }

            if let error = supabaseManager.authError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.warning)
            }
        }
    }

    private func enableSync() {
        isSigningIn = true
        Task {
            do {
                try await supabaseManager.signInAnonymously()
            } catch {
                // Error is stored in supabaseManager.authError
            }
            isSigningIn = false
        }
    }

    // MARK: - Experience Section

    private var experienceSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("EXPERIENCE")
                .sectionHeader()

            VStack(spacing: DesignSystem.Spacing.xs) {
                // Minimal Mode
                SettingRow(
                    icon: localPreferences.isMinimalModeEnabled ? "leaf.fill" : "leaf",
                    iconColor: accent,
                    title: "Minimal Mode",
                    subtitle: localPreferences.isMinimalModeEnabled
                        ? "Calm, tool-like experience"
                        : "Includes progress celebrations"
                ) {
                    Toggle("", isOn: $localPreferences.isMinimalModeEnabled)
                        .tint(accent)
                        .labelsHidden()
                }

                // Show what minimal mode does when enabled
                if localPreferences.isMinimalModeEnabled {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.positive)

                        Text("Focus on your work, not on points. XP, levels, achievements, and popups are hidden.")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                } else {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textMuted)

                        Text("Shows XP, levels, achievements, and celebration popups after sessions")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
            }
        }
    }

    // MARK: - Social Section

    private var socialSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("SOCIAL")
                .sectionHeader()

            VStack(spacing: DesignSystem.Spacing.xs) {
                // Leaderboard
                NavigationLink {
                    LeaderboardView()
                } label: {
                    SettingRow(
                        icon: "trophy",
                        iconColor: accent,
                        title: "Leaderboard",
                        subtitle: "Compete with others"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                .buttonStyle(.plain)

                // Challenges
                NavigationLink {
                    ChallengesView()
                } label: {
                    SettingRow(
                        icon: "flag.checkered",
                        iconColor: accent,
                        title: "Challenges",
                        subtitle: "Join focus challenges"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                .buttonStyle(.plain)

                // Friends
                NavigationLink {
                    FriendsView()
                } label: {
                    SettingRow(
                        icon: "person.2",
                        iconColor: accent,
                        title: "Friends",
                        subtitle: "Add accountability partners"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                .buttonStyle(.plain)

                // Family Plan
                NavigationLink {
                    FamilyPlanView()
                } label: {
                    SettingRow(
                        icon: "person.3.fill",
                        iconColor: accent,
                        title: "Family Plan",
                        subtitle: "Share with up to 5 people"
                    ) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("NOTIFICATIONS")
                .sectionHeader()

            VStack(spacing: DesignSystem.Spacing.xs) {
                // Notification permission status
                SettingRow(
                    icon: "bell.badge",
                    iconColor: accent,
                    title: "Push Notifications",
                    subtitle: notificationManager.isAuthorized ? "Enabled" : "Get notified about lock requests"
                ) {
                    if notificationManager.isAuthorized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                    } else {
                        Button("Enable") {
                            Task {
                                try? await notificationManager.requestAuthorization()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // Info text
                if !notificationManager.isAuthorized {
                    Text("Enable notifications to receive alerts when family members request focus locks.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.top, DesignSystem.Spacing.xs)
                }
            }
        }
    }

    #if os(iOS)
    // MARK: - Focus Sync Section (iOS)

    private var focusSyncSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("SYSTEM FOCUS")
                .sectionHeader()

            VStack(spacing: DesignSystem.Spacing.xs) {
                // System Focus Status
                SettingRow(
                    icon: "moon.fill",
                    iconColor: .indigo,
                    title: "System Focus",
                    subtitle: systemFocusManager.isSystemFocusActive
                        ? (systemFocusManager.currentFocusName ?? "Active")
                        : "Not active"
                ) {
                    Circle()
                        .fill(systemFocusManager.isSystemFocusActive ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }

                // Sync with System Focus toggle
                SettingRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: accent,
                    title: "Auto-block with Focus",
                    subtitle: "Start blocking when system Focus activates"
                ) {
                    Toggle("", isOn: Binding(
                        get: { systemFocusManager.isSyncWithSystemFocusEnabled },
                        set: { systemFocusManager.setSyncWithSystemFocus($0) }
                    ))
                    .labelsHidden()
                    .tint(accent)
                }

                // Focus Filter info
                Text("Configure Focus Filters in Settings → Focus to automatically start sessions.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.top, DesignSystem.Spacing.xs)
            }
        }
    }

    // MARK: - Blocking Section (iOS)

    private var blockingSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("BLOCKING")
                .sectionHeader()

            VStack(spacing: DesignSystem.Spacing.xs) {
                // Screen Time
                SettingRow(
                    icon: "hourglass",
                    iconColor: accent,
                    title: "Screen Time",
                    subtitle: blockEnforcementManager.isScreenTimeAuthorized ? "Authorized" : "Required for app blocking"
                ) {
                    if blockEnforcementManager.isScreenTimeAuthorized {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                    } else {
                        Button("Authorize") {
                            Task {
                                try? await blockEnforcementManager.requestScreenTimeAuthorization()
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(accent)
                        }
                    }
                }

                // Safari Blocker
                SettingRow(
                    icon: "safari",
                    iconColor: accent,
                    title: "Safari Blocker",
                    subtitle: contentBlocker.isEnabled ? "Enabled" : "Enable in Safari Settings"
                ) {
                    if contentBlocker.isEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                    } else {
                        Button("Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(accent)
                        }
                    }
                }
            }
        }
        .onAppear {
            blockEnforcementManager.checkScreenTimeAuthorization()
            contentBlocker.checkBlockerStatus()
        }
    }
    #endif

    #if os(macOS)
    // MARK: - Network Extension (macOS)

    private var networkExtensionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("BLOCKING")
                .sectionHeader()

            SettingRow(
                icon: "network",
                iconColor: accent,
                title: "Content Filter",
                subtitle: NetworkExtensionManager.shared.status
            ) {
                if NetworkExtensionManager.shared.isEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                }
            }
        }
    }
    #endif

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("ABOUT")
                .sectionHeader()

            VStack(spacing: 0) {
                HStack {
                    Text("Version")
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(DesignSystem.Spacing.md)

                Divider()
                    .background(AppTheme.border)

                Link(destination: URL(string: "https://github.com/yourcompany/refocus")!) {
                    HStack {
                        Text("Source Code")
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.cardBackground)
            }
        }
    }
}

// MARK: - Settings Card Modifier

extension View {
    func settingsCard() -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.cardBackground)
            }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(SupabaseManager.shared)
    .environmentObject(BlockEnforcementManager.shared)
}
