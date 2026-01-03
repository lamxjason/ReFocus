import SwiftUI

struct ContentView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var timerSyncManager: TimerSyncManager

    var body: some View {
        Group {
            #if os(iOS)
            iOSContentView()
            #elseif os(macOS)
            MacContentView()
            #endif
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - iOS Layout

#if os(iOS)
struct iOSContentView: View {
    @EnvironmentObject var blockEnforcementManager: BlockEnforcementManager
    @StateObject private var contentBlocker = SafariContentBlockerManager.shared
    @StateObject private var modeManager = FocusModeManager.shared
    @StateObject private var scheduleManager = ScheduleManager.shared
    @State private var selectedTab = 0
    @State private var showingOnboarding = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("focusViewMode") private var focusViewMode: String = "Timer"

    /// Current accent color based on view mode (Timer vs Schedule)
    private var accentColor: Color {
        if focusViewMode == "Schedule" {
            // Schedule mode - use schedule color
            if let active = scheduleManager.activeSchedule {
                return active.primaryColor
            }
            if let firstEnabled = scheduleManager.schedules.first(where: { $0.isEnabled }) {
                return firstEnabled.primaryColor
            }
            return DesignSystem.Colors.accent
        } else {
            // Timer mode - use selected mode color
            guard let mode = modeManager.selectedMode else {
                return DesignSystem.Colors.accent
            }
            return mode.primaryColor
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                FocusSessionView(viewModeBinding: $focusViewMode)
            }
            .tabItem {
                Label("Focus", systemImage: "moon.stars")
            }
            .tag(0)

            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar.fill")
            }
            .tag(1)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(2)
        }
        .tint(accentColor)
        .animation(.easeInOut(duration: 0.3), value: accentColor)
        .onAppear {
            checkPermissions()
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingFlowView {
                showingOnboarding = false
                hasCompletedOnboarding = true
            }
            .environmentObject(blockEnforcementManager)
        }
    }

    private func checkPermissions() {
        blockEnforcementManager.checkScreenTimeAuthorization()
        contentBlocker.checkBlockerStatus()

        // Show onboarding if not completed and missing permissions
        if !hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingOnboarding = true
            }
        }
    }
}

// MARK: - Onboarding Flow

struct OnboardingFlowView: View {
    @EnvironmentObject var blockEnforcementManager: BlockEnforcementManager
    @StateObject private var contentBlocker = SafariContentBlockerManager.shared
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var isRequesting = false

    private let totalSteps = 3

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Capsule()
                            .fill(step <= currentStep ? DesignSystem.Colors.accent : DesignSystem.Colors.backgroundCard)
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.xl)

                // Content
                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    screenTimeStep.tag(1)
                    safariStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Welcome Step

    private var welcomeStep: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Icon - Moon and stars representing dreams and aspirations
            ZStack {
                Image(systemName: "moon.stars")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            // Title
            Text("Dream Bigger")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            // Tagline
            Text("ReFocus helps you achieve your goals by eliminating distractions. Every focused minute brings you closer to your dreams.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            // Quote
            Text("\"The future belongs to those who believe in the beauty of their dreams.\"")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.top, DesignSystem.Spacing.md)

            Spacer()

            Button {
                withAnimation { currentStep = 1 }
            } label: {
                Text("Let's Begin")
            }
            .buttonStyle(.primary)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    // MARK: - Screen Time Step

    private var screenTimeStep: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            Image(systemName: "hourglass.badge.plus")
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(DesignSystem.Colors.accent)

            Text("Block Distracting Apps")
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("Screen Time lets ReFocus block apps during focus sessions. Your goals deserve your full attention.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            if blockEnforcementManager.isScreenTimeAuthorized {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignSystem.Colors.success)
                    Text("Screen Time Enabled")
                        .foregroundStyle(DesignSystem.Colors.success)
                }
                .font(DesignSystem.Typography.bodyMedium)
            }

            Spacer()

            VStack(spacing: DesignSystem.Spacing.md) {
                if !blockEnforcementManager.isScreenTimeAuthorized {
                    Button {
                        requestScreenTime()
                    } label: {
                        if isRequesting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Enable Screen Time")
                        }
                    }
                    .buttonStyle(.primary)
                    .disabled(isRequesting)
                }

                Button {
                    withAnimation { currentStep = 2 }
                } label: {
                    Text(blockEnforcementManager.isScreenTimeAuthorized ? "Continue" : "Skip for Now")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(blockEnforcementManager.isScreenTimeAuthorized ? DesignSystem.Colors.accent : DesignSystem.Colors.textMuted)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    // MARK: - Safari Step

    private var safariStep: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            if contentBlocker.isEnabled {
                // Success state
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(DesignSystem.Colors.success)

                Text("Safari Blocker Enabled!")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Distracting websites will be blocked in Safari during your focus sessions.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            } else {
                // Setup instructions
                Image(systemName: "safari")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(DesignSystem.Colors.accent)

                Text("Enable Safari Blocker")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Follow these steps to block distracting websites:")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                // Step-by-step instructions
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    safariSetupStep(number: 1, icon: "gear", text: "Open the Settings app")
                    safariSetupStep(number: 2, icon: "safari", text: "Scroll down and tap Safari")
                    safariSetupStep(number: 3, icon: "puzzlepiece.extension", text: "Tap Extensions")
                    safariSetupStep(number: 4, icon: "togglepower", text: "Enable ReFocus Blocker")
                }
                .padding(DesignSystem.Spacing.lg)
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                        .fill(DesignSystem.Colors.backgroundCard)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            Spacer()

            VStack(spacing: DesignSystem.Spacing.md) {
                if !contentBlocker.isEnabled {
                    Button {
                        // Try to open Safari settings directly (may not work on all iOS versions)
                        if let safariSettingsURL = URL(string: "App-Prefs:SAFARI"),
                           UIApplication.shared.canOpenURL(safariSettingsURL) {
                            UIApplication.shared.open(safariSettingsURL)
                        } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            // Fallback to general settings
                            UIApplication.shared.open(settingsURL)
                        }
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "arrow.up.forward.app")
                            Text("Open Settings App")
                        }
                    }
                    .buttonStyle(.primary)

                    Text("Then navigate: Safari → Extensions → ReFocus Blocker")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    onComplete()
                } label: {
                    Text(contentBlocker.isEnabled ? "Start Focusing" : "I'll Do This Later")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(contentBlocker.isEnabled ? DesignSystem.Colors.accent : DesignSystem.Colors.textMuted)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .onAppear {
            contentBlocker.checkBlockerStatus()
        }
    }

    private func safariSetupStep(number: Int, icon: String, text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Step number
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(DesignSystem.Colors.accent)
                }

            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 28)

            // Text
            Text(text)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Spacer()
        }
    }

    // MARK: - Actions

    private func requestScreenTime() {
        isRequesting = true
        Task {
            do {
                try await blockEnforcementManager.requestScreenTimeAuthorization()
            } catch {
                print("Screen Time authorization failed: \(error)")
            }
            isRequesting = false
        }
    }
}
#endif

// MARK: - macOS Layout

#if os(macOS)
struct MacContentView: View {
    @State private var selectedSection: MacSection = .focus

    enum MacSection: String, CaseIterable, Identifiable {
        case focus = "Focus"
        case websites = "Websites"
        case apps = "Apps"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .focus: return "timer"
            case .websites: return "globe"
            case .apps: return "app.badge"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(MacSection.allCases, selection: $selectedSection) { section in
                HStack(spacing: 12) {
                    Image(systemName: section.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(selectedSection == section ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                        .frame(width: 24)

                    Text(section.rawValue)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(selectedSection == section ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    if selectedSection == section {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.accentSoft)
                    }
                }
                .contentShape(Rectangle())
                .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.backgroundElevated)
        } detail: {
            Group {
                switch selectedSection {
                case .focus:
                    MacFocusView()
                case .websites:
                    MacWebsitesView()
                case .apps:
                    MacAppsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Colors.background)
        }
        .navigationSplitViewStyle(.balanced)
    }
}
#endif

#Preview {
    ContentView()
        .environmentObject(SupabaseManager.shared)
        .environmentObject(TimerSyncManager.shared)
        .environmentObject(WebsiteSyncManager.shared)
        .environmentObject(BlockEnforcementManager.shared)
}
