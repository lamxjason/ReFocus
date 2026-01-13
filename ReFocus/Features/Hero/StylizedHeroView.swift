import SwiftUI

// MARK: - Stylized Hero View (Clean, Modern Look)

/// A stylized hero representation using SF Symbols and layered effects
/// Looks professional without needing external sprite assets
struct StylizedHeroView: View {
    let heroClass: HeroClass
    let tier: EvolutionTier
    var size: CGFloat = 100
    var animated: Bool = true

    @State private var isAnimating = false
    @State private var glowPulse: CGFloat = 0.6

    var body: some View {
        ZStack {
            // Outer glow ring (tier-based)
            if tier >= .adventurer {
                outerRing
            }

            // Background circle with gradient
            backgroundCircle

            // Character icon with layered effects
            characterIcon

            // Weapon/accessory indicator
            weaponIndicator
                .offset(x: size * 0.28, y: size * 0.1)

            // Class-specific particle effects
            if tier >= .champion {
                particleEffects
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowPulse = 1.0
                }
                isAnimating = true
            }
        }
    }

    // MARK: - Background

    private var backgroundCircle: some View {
        ZStack {
            // Base circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            heroClass.primaryColor.opacity(0.4),
                            heroClass.primaryColor.opacity(0.15),
                            DesignSystem.Colors.backgroundCard
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.45
                    )
                )
                .frame(width: size * 0.8, height: size * 0.8)

            // Inner highlight
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            heroClass.primaryColor.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.75, height: size * 0.75)

            // Border
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            heroClass.primaryColor.opacity(0.6),
                            heroClass.primaryColor.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: tier >= .hero ? 3 : 2
                )
                .frame(width: size * 0.8, height: size * 0.8)
        }
    }

    // MARK: - Character Icon

    private var characterIcon: some View {
        ZStack {
            // Shadow/depth layer
            Image(systemName: heroClass.characterIcon)
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.3))
                .offset(y: 2)

            // Main character icon
            Image(systemName: heroClass.characterIcon)
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            .white,
                            heroClass.primaryColor.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: heroClass.primaryColor.opacity(0.5), radius: 6)
        }
        .scaleEffect(animated && isAnimating ? 1.02 : 1.0)
    }

    // MARK: - Weapon Indicator

    private var weaponIndicator: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Colors.backgroundCard)
                .frame(width: size * 0.22, height: size * 0.22)

            Circle()
                .strokeBorder(heroClass.primaryColor.opacity(0.5), lineWidth: 1)
                .frame(width: size * 0.22, height: size * 0.22)

            Image(systemName: heroClass.weaponIcon)
                .font(.system(size: size * 0.1, weight: .semibold))
                .foregroundStyle(heroClass.primaryColor)
        }
    }

    // MARK: - Outer Ring

    private var outerRing: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [
                        heroClass.primaryColor.opacity(0.5),
                        heroClass.primaryColor.opacity(0.1),
                        heroClass.primaryColor.opacity(0.5)
                    ],
                    center: .center
                ),
                lineWidth: tier == .legend ? 3 : 2
            )
            .frame(width: size * 0.95, height: size * 0.95)
            .opacity(glowPulse * 0.8)
            .blur(radius: 2)
    }

    // MARK: - Particle Effects

    private var particleEffects: some View {
        ForEach(0..<(tier == .legend ? 6 : 4), id: \.self) { i in
            let angle = Double(i) * (tier == .legend ? .pi / 3 : .pi / 2)
            let radius = size * 0.42

            Image(systemName: tier == .legend ? "sparkle" : "circle.fill")
                .font(.system(size: tier == .legend ? size * 0.06 : size * 0.03))
                .foregroundStyle(tier == .legend ? Color.white : heroClass.primaryColor)
                .offset(
                    x: cos(angle + (isAnimating ? 0.3 : 0)) * radius,
                    y: sin(angle + (isAnimating ? 0.3 : 0)) * radius
                )
                .opacity(glowPulse * 0.9)
        }
    }
}

// MARK: - Hero Class Extensions

extension HeroClass {
    /// SF Symbol for character representation
    var characterIcon: String {
        switch self {
        case .warrior: return "figure.martial.arts"
        case .mage: return "wand.and.stars"
        case .rogue: return "figure.run"
        case .paladin: return "shield.checkered"
        case .sage: return "book.closed.fill"
        case .shadow: return "moon.stars.fill"
        }
    }

    /// SF Symbol for weapon
    var weaponIcon: String {
        switch self {
        case .warrior: return "shield.lefthalf.filled"
        case .mage: return "sparkles"
        case .rogue: return "bolt.fill"
        case .paladin: return "cross.fill"
        case .sage: return "leaf.fill"
        case .shadow: return "moon.fill"
        }
    }
}

// MARK: - Full Hero Display with Stylized View

struct StylizedHeroDisplayView: View {
    let hero: FocusHero
    var size: CGFloat = 120
    var showName: Bool = false
    var showTier: Bool = true

    @State private var showingInfo = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Main hero view
            Button {
                showingInfo = true
            } label: {
                ZStack {
                    // Ground shadow
                    Ellipse()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: size * 0.5, height: size * 0.1)
                        .offset(y: size * 0.42)
                        .blur(radius: 4)

                    // Hero
                    StylizedHeroView(
                        heroClass: hero.heroClass,
                        tier: hero.evolutionTier,
                        size: size,
                        animated: true
                    )
                }
            }
            .buttonStyle(.plain)

            // Tier badge
            if showTier {
                tierBadge
            }

            // Name
            if showName {
                Text(hero.name)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
        }
        .sheet(isPresented: $showingInfo) {
            HeroInfoPopup(hero: hero, isPresented: $showingInfo)
        }
    }

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

// MARK: - Compact Version for Cards

struct CompactStylizedHeroView: View {
    let hero: FocusHero
    var size: CGFloat = 60

    var body: some View {
        StylizedHeroView(
            heroClass: hero.heroClass,
            tier: hero.evolutionTier,
            size: size,
            animated: true
        )
    }
}

// MARK: - Preview

#Preview("Stylized Heroes") {
    ScrollView {
        VStack(spacing: 30) {
            Text("Stylized Hero System")
                .font(.headline)
                .foregroundStyle(.white)

            // All classes
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(HeroClass.allCases, id: \.self) { heroClass in
                    VStack(spacing: 8) {
                        StylizedHeroView(
                            heroClass: heroClass,
                            tier: .champion,
                            size: 90,
                            animated: true
                        )

                        Text(heroClass.displayName)
                            .font(.caption)
                            .foregroundStyle(heroClass.primaryColor)
                    }
                }
            }
            .padding()

            // Evolution tiers
            Text("Evolution Tiers (Warrior)")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top)

            HStack(spacing: 16) {
                ForEach(EvolutionTier.allCases, id: \.self) { tier in
                    VStack(spacing: 6) {
                        StylizedHeroView(
                            heroClass: .warrior,
                            tier: tier,
                            size: 55,
                            animated: tier == .legend
                        )

                        Text(tier.displayName)
                            .font(.system(size: 9))
                            .foregroundStyle(tier.badgeColor)
                    }
                }
            }

            // Full display
            Text("Full Display")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top)

            StylizedHeroDisplayView(
                hero: FocusHero(
                    name: "Kael",
                    heroClass: .warrior,
                    currentLevel: 35,
                    currentXP: 5000
                ),
                size: 140,
                showName: true,
                showTier: true
            )
        }
        .padding()
    }
    .background(Color.black)
}
