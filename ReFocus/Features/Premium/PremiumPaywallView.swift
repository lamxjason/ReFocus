import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var premiumManager = PremiumManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color(hex: "0A0A10"),
                        Color(hex: "0F1628"),
                        Color(hex: "1A2744").opacity(0.5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Header
                        headerSection
                            .padding(.top, DesignSystem.Spacing.xl)

                        // Features
                        featuresSection

                        // Products
                        if !premiumManager.products.isEmpty {
                            productsSection
                        } else if premiumManager.isLoading {
                            ProgressView()
                                .tint(DesignSystem.Colors.accent)
                                .padding()
                        }

                        // Error
                        if let error = premiumManager.purchaseError {
                            Text(error)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.error)
                                .padding()
                        }

                        // Restore
                        restoreButton

                        // Terms
                        termsSection
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Premium")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(hex: "0A0A10"))
        #endif
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Icon with aurora gradient
            ZStack {
                // Glow effect
                Circle()
                    .fill(RichGradients.aurora)
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .opacity(0.6)

                // Main circle
                ZStack {
                    Circle()
                        .fill(RichGradients.aurora)
                        .frame(width: 90, height: 90)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            }

            Text("Unlock Session Lock")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)

            Text("Commit fully to your focus sessions")
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            GradientFeatureRow(
                icon: "lock.fill",
                title: "Session Lock",
                description: "Sessions are fully locked until complete",
                gradient: RichGradients.midnight
            )

            GradientFeatureRow(
                icon: "shield.checkered",
                title: "Regret Prevention",
                description: "Auto-block during vulnerable hours",
                gradient: RichGradients.twilight
            )

            GradientFeatureRow(
                icon: "icloud",
                title: "Cross-Device Sync",
                description: "Sync sessions and settings across all devices",
                gradient: RichGradients.ocean
            )

            GradientFeatureRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Focus Analytics",
                description: "Track your productivity patterns",
                gradient: RichGradients.aurora
            )
        }
    }

    // MARK: - Products

    private var productsSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(premiumManager.products.enumerated()), id: \.element.id) { index, product in
                ProductRow(
                    product: product,
                    onPurchase: {
                        Task {
                            let success = await premiumManager.purchase(product)
                            if success {
                                dismiss()
                            }
                        }
                    },
                    isRecommended: product.id == PremiumManager.yearlyProductId
                )
            }
        }
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task {
                await premiumManager.restorePurchases()
                if premiumManager.isPremium {
                    dismiss()
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .disabled(premiumManager.isLoading)
    }

    // MARK: - Terms

    private var termsSection: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period.")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: DesignSystem.Spacing.md) {
                Link("Terms of Use", destination: URL(string: "https://example.com/terms")!)
                Text("•")
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
            }
            .font(DesignSystem.Typography.caption)
            .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .padding(.top, DesignSystem.Spacing.md)
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(DesignSystem.Colors.accentSoft)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(description)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Gradient Feature Row

struct GradientFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let gradient: LinearGradient

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(gradient)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(.white)

                Text(description)
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

// MARK: - Product Row

struct ProductRow: View {
    let product: Product
    let onPurchase: () -> Void
    var isRecommended: Bool = false

    @StateObject private var premiumManager = PremiumManager.shared

    var body: some View {
        Button(action: onPurchase) {
            ZStack(alignment: .topTrailing) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.displayName)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(isRecommended ? .white : DesignSystem.Colors.textPrimary)

                        if let subscription = product.subscription {
                            Text(subscriptionPeriodText(subscription.subscriptionPeriod))
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(isRecommended ? .white.opacity(0.7) : DesignSystem.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    Text(product.displayPrice)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isRecommended ? .white : DesignSystem.Colors.accent)
                }
                .padding(DesignSystem.Spacing.md)
                .padding(.vertical, isRecommended ? 4 : 0)
                .background {
                    if isRecommended {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .fill(RichGradients.aurora)
                    } else {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .fill(DesignSystem.Colors.backgroundCard)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .strokeBorder(
                            isRecommended ? .white.opacity(0.3) : DesignSystem.Colors.border,
                            lineWidth: isRecommended ? 2 : 1
                        )
                }

                // Best value badge
                if isRecommended {
                    Text("BEST VALUE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(Color(hex: "7DCEA0"))
                        }
                        .offset(x: -8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(premiumManager.isLoading)
    }

    private func subscriptionPeriodText(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day: return "per day"
        case .week: return "per week"
        case .month: return "per month"
        case .year: return "per year"
        @unknown default: return ""
        }
    }
}

#Preview {
    PremiumPaywallView()
}
