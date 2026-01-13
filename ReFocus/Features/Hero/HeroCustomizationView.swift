import SwiftUI

/// Full hero customization screen - view stats, equipment, evolution
struct HeroCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var heroManager = FocusHeroManager.shared
    @ObservedObject var statsManager = StatsManager.shared

    @State private var selectedTab: CustomizationTab = .stats
    @State private var showingEditSheet = false
    @State private var editedName: String = ""

    enum CustomizationTab: String, CaseIterable {
        case stats = "Stats"
        case equipment = "Equipment"
        case evolution = "Evolution"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                if let hero = heroManager.currentHero {
                    VStack(spacing: 0) {
                        // Hero display
                        heroHeader(hero)

                        // Tab selector
                        tabSelector

                        // Content
                        TabView(selection: $selectedTab) {
                            statsContent(hero)
                                .tag(CustomizationTab.stats)

                            equipmentContent(hero)
                                .tag(CustomizationTab.equipment)

                            evolutionContent(hero)
                                .tag(CustomizationTab.evolution)
                        }
                        #if os(iOS)
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        #endif
                    }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if let hero = heroManager.currentHero {
                            editedName = hero.name
                            showingEditSheet = true
                        }
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                heroEditSheet
            }
        }
    }

    // MARK: - Edit Sheet

    private var heroEditSheet: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                if let hero = heroManager.currentHero {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Hero preview
                        StylizedHeroView(
                            heroClass: hero.heroClass,
                            tier: hero.evolutionTier,
                            size: 120,
                            animated: true
                        )
                        .padding(.top, DesignSystem.Spacing.xl)

                        // Name field
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("HERO NAME")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .tracking(1)

                            TextField("Enter name", text: $editedName)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                        .fill(DesignSystem.Colors.backgroundCard)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                        .strokeBorder(hero.heroClass.primaryColor.opacity(0.5), lineWidth: 1)
                                }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                        // Class info (read-only)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("CLASS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .tracking(1)

                            HStack {
                                Text(hero.heroClass.displayName)
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundStyle(hero.heroClass.primaryColor)

                                Spacer()

                                Text("Level \(hero.currentLevel)")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                    .fill(DesignSystem.Colors.backgroundCard)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                        Spacer()

                        // Save button
                        Button {
                            saveHeroChanges()
                            showingEditSheet = false
                        } label: {
                            Text("Save Changes")
                        }
                        .buttonStyle(ColoredPrimaryButtonStyle(color: hero.heroClass.primaryColor))
                        .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.xxl)
                    }
                }
            }
            .navigationTitle("Edit Hero")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingEditSheet = false
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }

    private func saveHeroChanges() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        heroManager.renameHero(to: trimmedName)
    }

    // MARK: - Hero Header

    private func heroHeader(_ hero: FocusHero) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Stylized hero display
            StylizedHeroView(
                heroClass: hero.heroClass,
                tier: hero.evolutionTier,
                size: 140,
                animated: true
            )

            // Name and class
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(hero.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(hero.heroClass.displayName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(hero.heroClass.primaryColor)

                    Text("•")
                        .foregroundStyle(DesignSystem.Colors.textMuted)

                    Text("Level \(hero.currentLevel)")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                // Tier badge
                Text(hero.evolutionTier.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(hero.evolutionTier.badgeColor)
                    }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(CustomizationTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(selectedTab == tab
                            ? DesignSystem.Colors.accent
                            : DesignSystem.Colors.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background {
                            if selectedTab == tab {
                                Rectangle()
                                    .fill(DesignSystem.Colors.accent)
                                    .frame(height: 2)
                                    .offset(y: 14)
                            }
                        }
                }
            }
        }
        .padding(.horizontal)
        .background {
            Rectangle()
                .fill(DesignSystem.Colors.backgroundCard)
                .frame(height: 1)
                .offset(y: 18)
        }
    }

    // MARK: - Stats Content

    private func statsContent(_ hero: FocusHero) -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // XP Progress
                xpProgressCard(hero)

                // Stats grid
                statsGrid

                // Achievements
                achievementsSection
            }
            .padding()
        }
    }

    private func xpProgressCard(_ hero: FocusHero) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("EXPERIENCE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text("\(hero.currentXP) XP")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Text("\(hero.xpToNextLevel) to Level \(hero.currentLevel + 1)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignSystem.Colors.backgroundCard)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(hero.heroClass.primaryColor)
                            .frame(width: geo.size.width * hero.levelProgress)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundElevated)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DesignSystem.Spacing.md) {
            statCell(
                icon: "clock.fill",
                value: formatTime(statsManager.totalFocusTime),
                label: "Total Focus"
            )

            statCell(
                icon: "checkmark.circle.fill",
                value: "\(statsManager.sessions.filter { $0.wasCompleted }.count)",
                label: "Sessions"
            )

            statCell(
                icon: "flame.fill",
                value: "\(statsManager.currentStreak)",
                label: "Day Streak"
            )

            statCell(
                icon: "star.fill",
                value: "\(statsManager.xp)",
                label: "Total XP"
            )
        }
    }

    private func statCell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(DesignSystem.Colors.accent)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundElevated)
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("ACHIEVEMENTS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            if statsManager.achievements.isEmpty {
                Text("Complete focus sessions to earn achievements")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.sm) {
                    ForEach(statsManager.achievements.prefix(6)) { achievement in
                        VStack(spacing: 4) {
                            Image(systemName: achievement.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(DesignSystem.Colors.accent)

                            Text(achievement.name)
                                .font(.system(size: 10))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundElevated)
        }
    }

    // MARK: - Equipment Content

    private func equipmentContent(_ hero: FocusHero) -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Equipped items
                equippedSection(hero)

                // Inventory
                inventorySection
            }
            .padding()
        }
    }

    private func equippedSection(_ hero: FocusHero) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("EQUIPPED")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            HStack(spacing: DesignSystem.Spacing.md) {
                ForEach(EquipmentSlot.allCases, id: \.self) { slot in
                    equipmentSlotView(slot)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundElevated)
        }
    }

    private func equipmentSlotView(_ slot: EquipmentSlot) -> some View {
        let equipped = heroManager.equippedItem(for: slot)

        return VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(equipped != nil
                          ? equipped!.rarity.color.opacity(0.2)
                          : DesignSystem.Colors.backgroundCard)
                    .frame(width: 50, height: 50)

                if let item = equipped {
                    Image(systemName: slot.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(item.rarity.color)
                } else {
                    Image(systemName: slot.emptySlotIcon)
                        .font(.system(size: 18))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }
            }
            .overlay {
                if let item = equipped {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(item.rarity.color.opacity(0.5), lineWidth: 1)
                }
            }

            Text(slot.displayName)
                .font(.system(size: 9))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("INVENTORY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1)

                Spacer()

                Text("\(heroManager.ownedEquipment.count) items")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }

            if heroManager.ownedEquipment.isEmpty {
                Text("Complete sessions and achievements to unlock equipment")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.sm) {
                    ForEach(heroManager.ownedEquipment, id: \.id) { item in
                        inventoryItem(item)
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundElevated)
        }
    }

    private func inventoryItem(_ item: Equipment) -> some View {
        let isEquipped = heroManager.equippedItem(for: item.slot)?.id == item.id

        return Button {
            if isEquipped {
                heroManager.unequipSlot(item.slot)
            } else {
                heroManager.equipItem(item)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.rarity.color.opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: item.slot.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(item.rarity.color)

                if isEquipped {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignSystem.Colors.positive)
                        .offset(x: 20, y: -20)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isEquipped ? DesignSystem.Colors.positive : item.rarity.color.opacity(0.3),
                        lineWidth: isEquipped ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Evolution Content

    private func evolutionContent(_ hero: FocusHero) -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Evolution stages
                evolutionTimeline(hero)

                // Current tier info
                currentTierInfo(hero)
            }
            .padding()
        }
    }

    private func evolutionTimeline(_ hero: FocusHero) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("EVOLUTION PATH")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(EvolutionTier.allCases, id: \.self) { tier in
                        evolutionStage(tier, hero: hero)
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundElevated)
        }
    }

    private func evolutionStage(_ tier: EvolutionTier, hero: FocusHero) -> some View {
        let isUnlocked = hero.currentLevel >= tier.minLevel
        let isCurrent = hero.evolutionTier == tier

        return VStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                StylizedHeroView(
                    heroClass: hero.heroClass,
                    tier: tier,
                    size: 55,
                    animated: isCurrent
                )
                .opacity(isUnlocked ? 1.0 : 0.3)

                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }

                if isCurrent {
                    Circle()
                        .stroke(hero.heroClass.primaryColor, lineWidth: 2)
                        .frame(width: 60, height: 60)
                }
            }
            .frame(width: 60, height: 65)

            Text(tier.displayName)
                .font(.system(size: 10, weight: isCurrent ? .bold : .medium))
                .foregroundStyle(isCurrent ? hero.heroClass.primaryColor : DesignSystem.Colors.textSecondary)

            Text("Lv \(tier.minLevel)+")
                .font(.system(size: 9))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }

    private func currentTierInfo(_ hero: FocusHero) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("CURRENT TIER")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1)

            HStack(spacing: DesignSystem.Spacing.md) {
                // Tier badge
                Text(hero.evolutionTier.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(hero.evolutionTier.badgeColor)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(hero.evolutionTier.description)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    if let nextTier = nextTier(after: hero.evolutionTier) {
                        Text("Next: \(nextTier.displayName) at Level \(nextTier.minLevel)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundElevated)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func nextTier(after tier: EvolutionTier) -> EvolutionTier? {
        let all = EvolutionTier.allCases
        guard let index = all.firstIndex(of: tier), index + 1 < all.count else {
            return nil
        }
        return all[index + 1]
    }
}

// MARK: - Preview

#Preview("Hero Customization") {
    HeroCustomizationView()
}
