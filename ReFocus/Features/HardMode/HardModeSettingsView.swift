import SwiftUI

/// Settings view for configuring Strict Mode with commitment-based emergency exit
struct HardModeSettingsView: View {
    @StateObject private var hardModeManager = HardModeManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Enable toggle
                        enableSection

                        if hardModeManager.config.isEnabled {
                            // Commitment time selection
                            commitmentTimeSection

                            // Weekly limit
                            weeklyLimitSection

                            // Exit history
                            if !hardModeManager.exitHistory.isEmpty {
                                historySection
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Strict Mode")
            .navigationBarTitleDisplayMode(.inline)
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
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Enable Section

    private var enableSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Strict Mode")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        if !premiumManager.isPremium {
                            Text("PRO")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background {
                                    Capsule()
                                        .fill(DesignSystem.Colors.accent)
                                }
                        }
                    }

                    Text("Lock sessions with paid emergency exit")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { hardModeManager.config.isEnabled },
                    set: { newValue in
                        if newValue && !premiumManager.isPremium {
                            showingPaywall = true
                        } else {
                            hardModeManager.config.isEnabled = newValue
                        }
                    }
                ))
                .tint(DesignSystem.Colors.accent)
                .labelsHidden()
            }
            .padding(DesignSystem.Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.backgroundCard)
            }

            // Description
            Text("Sessions are completely locked. After the commitment period, PRO users can pay $1.99 for an emergency exit.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }

    // MARK: - Commitment Time Section

    private var commitmentTimeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("MINIMUM COMMITMENT")
                .sectionHeader()

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(CommitmentTier.allCases) { tier in
                    commitmentTierRow(tier)
                }
            }

            Text("How long you must focus before emergency exit becomes available. Choose 'Never' for fully locked sessions.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }

    private func commitmentTierRow(_ tier: CommitmentTier) -> some View {
        let isSelected = hardModeManager.config.minimumCommitmentMinutes == tier.rawValue

        return Button {
            withAnimation(DesignSystem.Animation.quick) {
                hardModeManager.config.minimumCommitmentMinutes = tier.rawValue
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(tier.displayName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)

                    Text(tier.description)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignSystem.Colors.accent)
                } else {
                    Circle()
                        .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isSelected ? DesignSystem.Colors.accentSoft : DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .strokeBorder(
                        isSelected ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.border,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Escalating Pricing Section

    private var weeklyLimitSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("EXIT PRICING")
                .sectionHeader()

            VStack(spacing: DesignSystem.Spacing.sm) {
                // Current price info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current exit price")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Text("Price doubles with each use, max $50")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    Text(hardModeManager.config.currentExitPriceFormatted)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
                .padding(DesignSystem.Spacing.md)
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.backgroundCard)
                }

                // Monthly reset info
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))

                    Text("Resets to $2 each month • \(hardModeManager.config.exitsUsedThisMonth) exit\(hardModeManager.config.exitsUsedThisMonth == 1 ? "" : "s") this month")
                        .font(DesignSystem.Typography.caption)
                }
                .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("EXIT HISTORY")
                    .sectionHeader()

                Spacer()

                if hardModeManager.exitHistory.count > 0 {
                    Button("Clear") {
                        hardModeManager.clearHistory()
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.destructive)
                }
            }

            // Pattern insight
            if let warning = hardModeManager.patternWarning {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 14))

                    Text(warning)
                        .font(DesignSystem.Typography.caption)
                }
                .foregroundStyle(DesignSystem.Colors.caution)
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.caution.opacity(0.1))
                }
            }

            // Stats summary
            VStack(spacing: DesignSystem.Spacing.sm) {
                historyStatRow(
                    label: "Total emergency exits",
                    value: "\(hardModeManager.exitHistory.count)"
                )

                if let avgRating = hardModeManager.averageRegretRating {
                    historyStatRow(
                        label: "Average rating",
                        value: String(format: "%.1f/5", avgRating)
                    )
                }

                if let regretPct = hardModeManager.regretPercentage {
                    historyStatRow(
                        label: "Regretted",
                        value: "\(Int(regretPct))%"
                    )
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.backgroundCard)
            }
        }
    }

    private func historyStatRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
    }
}

#Preview {
    HardModeSettingsView()
}
