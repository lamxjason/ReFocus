import SwiftUI

/// Main hero display view - shows the pixel art character with equipment and effects
struct HeroDisplayView: View {
    let hero: FocusHero
    var size: CGFloat = 200
    var showBackground: Bool = true
    var animated: Bool = true
    var showTierBadge: Bool = true

    @State private var isAnimating = false
    @State private var glowOpacity: Double = 0.5
    @State private var pulseScale: CGFloat = 1.0

    private var heroManager: FocusHeroManager { .shared }

    // Calculate pixel size based on display size (sprite is 20x28)
    private var pixelSize: CGFloat {
        min(size / 28, size / 20) * 0.7
    }

    var body: some View {
        ZStack {
            // Background layer
            if showBackground {
                backgroundLayer
            }

            // Outer glow ring for higher tiers
            if hero.evolutionTier >= .adventurer {
                outerGlowRing
            }

            // Platform/ground effect
            groundShadow

            // Hero pixel art sprite with frame
            heroContainer

            // Tier badge
            if showTierBadge {
                tierBadge
                    .offset(y: size / 2 + 8)
            }
        }
        .frame(width: size, height: size + (showTierBadge ? 30 : 0))
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                    glowOpacity = 0.8
                }
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    pulseScale = 1.05
                }
            }
        }
    }

    // MARK: - Hero Container with Frame

    private var heroContainer: some View {
        ZStack {
            // Inner glow behind sprite
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            hero.heroClass.primaryColor.opacity(0.4),
                            hero.heroClass.primaryColor.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.35
                    )
                )
                .frame(width: size * 0.7, height: size * 0.7)
                .scaleEffect(animated ? pulseScale : 1.0)

            // Pixel art sprite
            heroPixelSprite
                .scaleEffect(animated && isAnimating ? 1.02 : 1.0)

            // Equipment indicators
            equipmentIndicators
        }
    }

    // MARK: - Pixel Art Hero Sprite

    private var heroPixelSprite: some View {
        PixelArtView(
            pixels: HeroSpriteGenerator.generateSprite(
                heroClass: hero.heroClass,
                tier: hero.evolutionTier,
                hasAscended: hero.hasAscended
            ),
            pixelSize: pixelSize,
            animated: animated
        )
        .shadow(color: hero.heroClass.primaryColor.opacity(0.5), radius: 12)
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }

    // MARK: - Outer Glow Ring

    private var outerGlowRing: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            hero.heroClass.primaryColor.opacity(0.4),
                            hero.heroClass.primaryColor.opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: hero.evolutionTier >= .champion ? 2 : 1
                )
                .frame(width: size * 0.85, height: size * 0.85)
                .blur(radius: 3)
                .opacity(glowOpacity * 0.6)

            // Sparkles for legend tier
            if hero.evolutionTier == .legend {
                legendSparkles
            }

            // Ascended golden particles
            if hero.hasAscended {
                ascendedStars
            }
        }
    }

    private var legendSparkles: some View {
        ForEach(0..<6, id: \.self) { i in
            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
                .offset(
                    x: cos(Double(i) * .pi / 3 + (isAnimating ? 0.5 : 0)) * size * 0.42,
                    y: sin(Double(i) * .pi / 3 + (isAnimating ? 0.5 : 0)) * size * 0.42
                )
                .opacity(glowOpacity * 0.8)
                .blur(radius: 1)
        }
    }

    private var ascendedStars: some View {
        ForEach(0..<5, id: \.self) { i in
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.035))
                .foregroundStyle(Color(hex: "FFD700"))
                .offset(
                    x: cos(Double(i) * .pi / 2.5) * size * 0.4,
                    y: sin(Double(i) * .pi / 2.5) * size * 0.4
                )
                .opacity(glowOpacity)
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            // Gradient background circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            hero.heroClass.primaryColor.opacity(0.2),
                            hero.heroClass.primaryColor.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
        }
    }

    // MARK: - Ground Shadow

    private var groundShadow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.1),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.25
                )
            )
            .frame(width: size * 0.45, height: size * 0.1)
            .offset(y: size * 0.3)
            .blur(radius: 3)
    }

    // MARK: - Equipment Indicators

    private var equipmentIndicators: some View {
        ZStack {
            // Weapon indicator (right side)
            if let weapon = heroManager.equippedItem(for: .weapon) {
                Image(systemName: weaponIcon(for: weapon))
                    .font(.system(size: size * 0.08, weight: .semibold))
                    .foregroundStyle(weapon.rarity.color)
                    .offset(x: size * 0.3, y: -size * 0.05)
                    .shadow(color: weapon.rarity.color.opacity(0.6), radius: 4)
            }

            // Pet companion (left side, floating)
            if let accessory = heroManager.equippedItem(for: .accessory),
               accessory.id.contains("pet") {
                petCompanion(for: accessory)
            }

            // Aura effect (around character)
            if let aura = heroManager.equippedItem(for: .aura) {
                auraEffect(for: aura)
            }
        }
    }

    private func weaponIcon(for weapon: Equipment) -> String {
        if weapon.id.contains("staff") || weapon.id.contains("wand") {
            return "wand.and.stars"
        } else if weapon.id.contains("dagger") || weapon.id.contains("blade") {
            return "bolt.fill"
        } else if weapon.id.contains("bow") {
            return "arrow.up.right"
        } else {
            return "shield.lefthalf.filled"
        }
    }

    private func petCompanion(for accessory: Equipment) -> some View {
        let icon: String
        let color: Color

        switch accessory.id {
        case "accessory_pet_dragon":
            icon = "flame.fill"
            color = Color(hex: "FF6B35")
        case "accessory_pet_fairy":
            icon = "sparkles"
            color = Color(hex: "FF69B4")
        case "accessory_pet_owl":
            icon = "moon.fill"
            color = Color(hex: "9B59B6")
        default:
            icon = "heart.fill"
            color = .pink
        }

        return Image(systemName: icon)
            .font(.system(size: size * 0.07))
            .foregroundStyle(color)
            .offset(x: -size * 0.3, y: -size * 0.2)
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .shadow(color: color.opacity(0.5), radius: 4)
    }

    private func auraEffect(for aura: Equipment) -> some View {
        Circle()
            .stroke(
                auraColor(for: aura.id).opacity(0.4),
                lineWidth: 3
            )
            .blur(radius: 6)
            .opacity(glowOpacity)
            .frame(width: size * 0.75, height: size * 0.75)
    }

    private func auraColor(for id: String) -> Color {
        switch id {
        case "aura_subtle": return .white
        case "aura_flame": return Color(hex: "FF6B35")
        case "aura_frost": return Color(hex: "00CED1")
        case "aura_lightning": return Color(hex: "FFD700")
        case "aura_celestial": return Color(hex: "E6E6FA")
        case "aura_void": return Color(hex: "4B0082")
        default: return hero.heroClass.primaryColor
        }
    }

    // MARK: - Tier Badge

    private var tierBadge: some View {
        HStack(spacing: 4) {
            if hero.evolutionTier >= .champion {
                Image(systemName: tierIcon)
                    .font(.system(size: 9))
            }
            Text(hero.evolutionTier.displayName)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(hero.evolutionTier.badgeColor)
                .shadow(color: hero.evolutionTier.badgeColor.opacity(0.4), radius: 4)
        }
    }

    private var tierIcon: String {
        switch hero.evolutionTier {
        case .apprentice: return "leaf"
        case .adventurer: return "figure.walk"
        case .champion: return "medal"
        case .hero: return "star.fill"
        case .legend: return "crown.fill"
        }
    }
}

// MARK: - Mini Hero View (for session display, compact card)

struct MiniHeroView: View {
    let hero: FocusHero
    let size: CGFloat

    private var pixelSize: CGFloat {
        size / 28
    }

    var body: some View {
        ZStack {
            // Subtle background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            hero.heroClass.primaryColor.opacity(0.25),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )

            PixelArtView(
                pixels: HeroSpriteGenerator.generateSprite(
                    heroClass: hero.heroClass,
                    tier: hero.evolutionTier,
                    hasAscended: hero.hasAscended
                ),
                pixelSize: pixelSize,
                animated: true
            )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Hero Info Popup (tap to show)

struct HeroInfoPopup: View {
    let hero: FocusHero
    @Binding var isPresented: Bool
    @ObservedObject var statsManager = StatsManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Hero display
            HeroDisplayView(
                hero: hero,
                size: 140,
                showTierBadge: true
            )

            // Name and class
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(hero.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Level \(hero.currentLevel)")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    Text("•")
                        .foregroundStyle(DesignSystem.Colors.textMuted)

                    Text(hero.heroClass.displayName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(hero.heroClass.primaryColor)
                }
            }

            // XP Progress
            VStack(spacing: DesignSystem.Spacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignSystem.Colors.backgroundCard)
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [hero.heroClass.primaryColor, hero.heroClass.primaryColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * hero.levelProgress, height: 10)
                    }
                }
                .frame(height: 10)

                Text("\(hero.xpToNextLevel) XP to Level \(hero.currentLevel + 1)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            // Quick stats
            HStack(spacing: DesignSystem.Spacing.lg) {
                statBubble(
                    icon: "clock.fill",
                    value: formatTime(statsManager.totalFocusTime),
                    label: "Focus Time"
                )
                statBubble(
                    icon: "flame.fill",
                    value: "\(statsManager.currentStreak)",
                    label: "Day Streak"
                )
                statBubble(
                    icon: "checkmark.circle.fill",
                    value: "\(statsManager.sessions.filter { $0.wasCompleted }.count)",
                    label: "Sessions"
                )
            }

            // Close button
            Button {
                isPresented = false
            } label: {
                Text("Close")
                    .font(DesignSystem.Typography.buttonSmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background {
                        Capsule()
                            .fill(DesignSystem.Colors.backgroundCard)
                    }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .fill(DesignSystem.Colors.backgroundElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .strokeBorder(hero.heroClass.primaryColor.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.5), radius: 20)
        .padding(DesignSystem.Spacing.xl)
    }

    private func statBubble(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(hero.heroClass.primaryColor)

            Text(value)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(width: 70)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Class Selection Card (for Hero Creation)

struct ClassSelectionCard: View {
    let heroClass: HeroClass
    let isSelected: Bool
    let isPremiumLocked: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Character preview using pixel art
                ZStack {
                    // Background glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    heroClass.primaryColor.opacity(isSelected ? 0.4 : 0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)

                    // Pixel art sprite
                    PixelArtView(
                        pixels: HeroSpriteGenerator.generateSprite(
                            heroClass: heroClass,
                            tier: .apprentice
                        ),
                        pixelSize: 3,
                        animated: isSelected
                    )

                    // Premium lock overlay
                    if isPremiumLocked {
                        ZStack {
                            Color.black.opacity(0.7)
                                .frame(width: 80, height: 100)

                            VStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 20))
                                Text("Premium")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(.white)
                        }
                    }
                }

                // Class name
                Text(heroClass.displayName)
                    .font(DesignSystem.Typography.headline)
                    .foregroundStyle(isSelected ? heroClass.primaryColor : DesignSystem.Colors.textPrimary)

                // Class description
                Text(heroClass.description)
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .fill(DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .strokeBorder(
                        isSelected ? heroClass.primaryColor : Color.clear,
                        lineWidth: 2
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isPremiumLocked)
        .opacity(isPremiumLocked ? 0.7 : 1)
    }
}

// MARK: - Evolution Stage Preview

struct EvolutionStagePreview: View {
    let heroClass: HeroClass
    let tier: EvolutionTier
    let isUnlocked: Bool
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                if isUnlocked {
                    PixelArtView(
                        pixels: HeroSpriteGenerator.generateSprite(
                            heroClass: heroClass,
                            tier: tier
                        ),
                        pixelSize: 2.5,
                        animated: isCurrent
                    )
                } else {
                    // Locked silhouette
                    PixelArtView(
                        pixels: HeroSpriteGenerator.generateSprite(
                            heroClass: heroClass,
                            tier: tier
                        ),
                        pixelSize: 2.5,
                        animated: false
                    )
                    .colorMultiply(Color.black)
                    .opacity(0.3)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                }

                // Current indicator ring
                if isCurrent {
                    Circle()
                        .stroke(heroClass.primaryColor, lineWidth: 2)
                        .frame(width: 70, height: 70)
                }
            }
            .frame(width: 70, height: 90)

            // Tier name
            Text(tier.displayName)
                .font(.system(size: 10, weight: isCurrent ? .bold : .medium))
                .foregroundStyle(isCurrent ? heroClass.primaryColor : DesignSystem.Colors.textSecondary)

            // Level range
            Text(tier.levelRangeText)
                .font(.system(size: 9))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
    }
}

// MARK: - Evolution Tier Extension

extension EvolutionTier {
    var levelRangeText: String {
        switch self {
        case .apprentice: return "Lv 1-10"
        case .adventurer: return "Lv 11-25"
        case .champion: return "Lv 26-50"
        case .hero: return "Lv 51-75"
        case .legend: return "Lv 76+"
        }
    }
}

// MARK: - Preview

#Preview("Hero Display") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 40) {
            // Large warrior display
            HeroDisplayView(
                hero: FocusHero(
                    name: "Kael",
                    heroClass: .warrior,
                    currentLevel: 35,
                    currentXP: 5000
                ),
                size: 180
            )

            // All classes at apprentice tier
            HStack(spacing: 12) {
                ForEach([HeroClass.warrior, .mage, .rogue], id: \.self) { heroClass in
                    VStack {
                        MiniHeroView(
                            hero: FocusHero(
                                name: "Test",
                                heroClass: heroClass,
                                currentLevel: 5,
                                currentXP: 500
                            ),
                            size: 80
                        )

                        Text(heroClass.displayName)
                            .font(.caption)
                            .foregroundStyle(heroClass.primaryColor)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview("Hero Info Popup") {
    ZStack {
        Color.black.ignoresSafeArea()

        HeroInfoPopup(
            hero: FocusHero(
                name: "Aria",
                heroClass: .mage,
                currentLevel: 25,
                currentXP: 3500
            ),
            isPresented: .constant(true)
        )
    }
}
