import SwiftUI

/// Hero creation flow - class selection and naming
struct HeroCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var heroManager = FocusHeroManager.shared
    @ObservedObject var premiumManager = PremiumManager.shared

    @State private var selectedClass: HeroClass = .warrior
    @State private var heroName: String = ""
    @State private var currentStep: CreationStep = .intro
    @State private var showingPaywall = false

    @FocusState private var isNameFieldFocused: Bool

    enum CreationStep {
        case intro
        case classSelection
        case naming
        case confirm
    }

    var body: some View {
        ZStack {
            // Background
            DesignSystem.Colors.background
                .ignoresSafeArea()

            // Ambient glow
            Circle()
                .fill(selectedClass.primaryColor.opacity(0.15))
                .blur(radius: 100)
                .frame(width: 300, height: 300)
                .offset(y: -100)

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                            .frame(width: 32, height: 32)
                            .background {
                                Circle()
                                    .fill(DesignSystem.Colors.backgroundCard)
                            }
                    }
                }
                .padding()

                // Content
                switch currentStep {
                case .intro:
                    introContent
                case .classSelection:
                    classSelectionContent
                case .naming:
                    namingContent
                case .confirm:
                    confirmContent
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
    }

    // MARK: - Intro

    private var introContent: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Hero icon
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Create Your Hero")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Your focus companion will grow stronger with every session you complete.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }

            // Features list
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                featureRow(icon: "arrow.up.circle.fill", text: "Level up through focus sessions")
                featureRow(icon: "sparkles", text: "Unlock equipment and cosmetics")
                featureRow(icon: "star.fill", text: "Evolve into powerful forms")
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.top, DesignSystem.Spacing.lg)

            Spacer()

            // CTA
            Button {
                withAnimation {
                    currentStep = .classSelection
                }
            } label: {
                Text("Choose Your Class")
            }
            .buttonStyle(.primary)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 24)

            Text(text)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Class Selection

    private var classSelectionContent: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("Choose Your Class")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Each class has a unique style")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .padding(.top, DesignSystem.Spacing.lg)

            // Class grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.md) {
                    ForEach(HeroClass.allCases, id: \.self) { heroClass in
                        classCard(heroClass)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            Spacer()

            // Continue button
            Button {
                withAnimation {
                    currentStep = .naming
                }
            } label: {
                Text("Continue")
            }
            .buttonStyle(ColoredPrimaryButtonStyle(color: selectedClass.primaryColor))
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    private func classCard(_ heroClass: HeroClass) -> some View {
        let isSelected = selectedClass == heroClass
        let isLocked = heroClass.isPremium && !premiumManager.isPremium

        return Button {
            if isLocked {
                showingPaywall = true
            } else {
                withAnimation(.spring(response: 0.3)) {
                    selectedClass = heroClass
                }
            }
        } label: {
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Stylized Hero
                ZStack {
                    StylizedHeroView(
                        heroClass: heroClass,
                        tier: .apprentice,
                        size: 80,
                        animated: isSelected
                    )
                    .opacity(isLocked ? 0.4 : 1.0)

                    // Lock overlay for premium
                    if isLocked {
                        VStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18))
                            Text("PRO")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(12)
                        .background {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                        }
                    }
                }
                .frame(height: 85)

                // Name
                HStack(spacing: 4) {
                    Text(heroClass.displayName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(isLocked ? DesignSystem.Colors.textMuted : DesignSystem.Colors.textPrimary)

                    if heroClass.isPremium && !isLocked {
                        Text("PRO")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background {
                                Capsule()
                                    .fill(DesignSystem.Colors.accent)
                            }
                    }
                }

                // Description
                Text(heroClass.description)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 30)
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isSelected
                          ? heroClass.primaryColor.opacity(0.15)
                          : DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .strokeBorder(
                        isSelected ? heroClass.primaryColor : Color.clear,
                        lineWidth: 2
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Naming

    private var namingContent: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Preview hero (stylized)
            StylizedHeroDisplayView(
                hero: FocusHero(
                    name: heroName.isEmpty ? "Hero" : heroName,
                    heroClass: selectedClass
                ),
                size: 140,
                showName: false,
                showTier: false
            )

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Name Your Hero")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Choose a name that inspires you")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            // Name input
            TextField("Enter name", text: $heroName)
                .font(.system(size: 20, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.backgroundCard)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .strokeBorder(selectedClass.primaryColor.opacity(0.5), lineWidth: 1)
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .focused($isNameFieldFocused)

            // Suggestion chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(nameSuggestions, id: \.self) { name in
                        Button {
                            heroName = name
                        } label: {
                            Text(name)
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background {
                                    Capsule()
                                        .fill(DesignSystem.Colors.backgroundCard)
                                }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            Spacer()

            // Continue button
            Button {
                isNameFieldFocused = false
                withAnimation {
                    currentStep = .confirm
                }
            } label: {
                Text("Continue")
            }
            .buttonStyle(ColoredPrimaryButtonStyle(color: selectedClass.primaryColor))
            .disabled(heroName.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .onAppear {
            isNameFieldFocused = true
        }
    }

    private var nameSuggestions: [String] {
        switch selectedClass {
        case .warrior:
            return ["Kael", "Theron", "Valor", "Atlas", "Titan"]
        case .mage:
            return ["Aria", "Luna", "Sage", "Nova", "Astrid"]
        case .rogue:
            return ["Shadow", "Dash", "Swift", "Echo", "Vex"]
        case .paladin:
            return ["Solace", "Dawn", "Light", "Hope", "Grace"]
        case .sage:
            return ["Elder", "Wise", "Oracle", "Mystic", "Zen"]
        case .shadow:
            return ["Void", "Night", "Shade", "Phantom", "Dusk"]
        }
    }

    // MARK: - Confirm

    private var confirmContent: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Final hero preview (stylized)
            StylizedHeroDisplayView(
                hero: FocusHero(
                    name: heroName,
                    heroClass: selectedClass
                ),
                size: 160,
                showName: false,
                showTier: true
            )

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(heroName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Level 1")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("•")
                        .foregroundStyle(DesignSystem.Colors.textMuted)

                    Text(selectedClass.displayName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(selectedClass.primaryColor)
                }

                Text("Apprentice")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(EvolutionTier.apprentice.badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(EvolutionTier.apprentice.badgeColor.opacity(0.2))
                    }
            }

            // Starter equipment
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("STARTER EQUIPMENT")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1)

                if let starterWeapon = EquipmentCatalog.starterWeapon(for: selectedClass) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: EquipmentSlot.weapon.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(starterWeapon.rarity.color)

                        Text(starterWeapon.name)
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.backgroundCard)
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()

            // Create button
            Button {
                createHero()
            } label: {
                Text("Begin Your Journey")
            }
            .buttonStyle(ColoredPrimaryButtonStyle(color: selectedClass.primaryColor))
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    // MARK: - Actions

    private func createHero() {
        let name = heroName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        heroManager.createHero(name: name, heroClass: selectedClass)
        dismiss()
    }
}

// MARK: - Preview

#Preview("Hero Creation") {
    HeroCreationView()
}
