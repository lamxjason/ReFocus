import SwiftUI

/// Compact hero card for displaying in Stats view
struct HeroCardView: View {
    @ObservedObject var heroManager = FocusHeroManager.shared
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            if let hero = heroManager.currentHero {
                heroContent(hero)
            } else {
                createHeroPrompt
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero Content

    private func heroContent(_ hero: FocusHero) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Stylized hero display
            StylizedHeroView(
                heroClass: hero.heroClass,
                tier: hero.evolutionTier,
                size: 75,
                animated: true
            )

            // Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Name and class
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(hero.name)
                        .font(DesignSystem.Typography.headline)
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text(hero.heroClass.displayName)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(hero.heroClass.primaryColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(hero.heroClass.primaryColor.opacity(0.2))
                        }
                }

                // Level and tier
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Level \(hero.currentLevel)")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("•")
                        .foregroundStyle(DesignSystem.Colors.textMuted)

                    Text(hero.evolutionTier.displayName)
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(hero.evolutionTier.badgeColor)
                }

                // XP Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignSystem.Colors.backgroundCard)
                                .frame(height: 8)

                            // Progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(hero.heroClass.primaryColor)
                                .frame(width: geo.size.width * hero.levelProgress, height: 8)
                        }
                    }
                    .frame(height: 8)

                    // XP text
                    Text("\(hero.xpToNextLevel) XP to next level")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
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
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .fill(DesignSystem.Colors.backgroundCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .strokeBorder(
                    hero.heroClass.primaryColor.opacity(0.3),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Create Hero Prompt

    private var createHeroPrompt: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Placeholder icon
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accentSoft)
                    .frame(width: 80, height: 80)

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            // Text
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Create Your Hero")
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Build a companion that grows with your focus")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            // Arrow
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(DesignSystem.Colors.accent)
        }
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .fill(DesignSystem.Colors.backgroundCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .strokeBorder(
                    DesignSystem.Colors.accent.opacity(0.3),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - Hero Stats Card

/// Shows hero stats in a grid format
struct HeroStatsCard: View {
    let hero: FocusHero
    @ObservedObject var statsManager = StatsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            Text("HERO STATS")
                .sectionHeader()

            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.sm) {
                statItem(
                    icon: "clock.fill",
                    value: formattedFocusTime,
                    label: "Total Focus"
                )

                statItem(
                    icon: "checkmark.circle.fill",
                    value: "\(statsManager.sessions.filter { $0.wasCompleted }.count)",
                    label: "Sessions"
                )

                statItem(
                    icon: "flame.fill",
                    value: "\(statsManager.currentStreak)",
                    label: "Day Streak"
                )

                statItem(
                    icon: "star.fill",
                    value: "\(statsManager.xp)",
                    label: "Total XP"
                )
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .fill(DesignSystem.Colors.backgroundCard)
        }
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(hero.heroClass.primaryColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedFocusTime: String {
        let hours = Int(statsManager.totalFocusTime) / 3600
        let minutes = (Int(statsManager.totalFocusTime) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Equipment Preview Row

/// Shows equipped items in a horizontal scroll
struct EquipmentPreviewRow: View {
    @ObservedObject var heroManager = FocusHeroManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("EQUIPMENT")
                .sectionHeader()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(EquipmentSlot.allCases, id: \.self) { slot in
                        equipmentSlotView(slot)
                    }
                }
            }
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
}

// MARK: - Preview

#Preview("Hero Card") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            HeroCardView {
                print("Tapped")
            }

            // Preview with no hero
            HeroCardView {
                print("Create hero")
            }
        }
        .padding()
    }
}
