import SwiftUI

// MARK: - Hero Sprite Asset System

/// Loads hero sprites from Assets catalog, with fallback to procedural generation
struct HeroSpriteView: View {
    let heroClass: HeroClass
    let tier: EvolutionTier
    let size: CGFloat
    let animated: Bool

    @State private var bounce: CGFloat = 0
    @State private var isAnimating = false

    init(heroClass: HeroClass, tier: EvolutionTier, size: CGFloat = 100, animated: Bool = true) {
        self.heroClass = heroClass
        self.tier = tier
        self.size = size
        self.animated = animated
    }

    var body: some View {
        Group {
            // Try to load from assets first
            if let image = HeroAssetCatalog.sprite(for: heroClass, tier: tier) {
                image
                    .interpolation(.none) // Keep pixel art crisp
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                // Fallback to procedural generation
                PixelArtView(
                    pixels: HeroSpriteGenerator.generateSprite(
                        heroClass: heroClass,
                        tier: tier
                    ),
                    pixelSize: size / 28,
                    animated: animated
                )
            }
        }
        .offset(y: animated ? bounce : 0)
        .shadow(color: heroClass.primaryColor.opacity(0.4), radius: 8)
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    bounce = -4
                }
            }
        }
    }
}

// MARK: - Asset Catalog

/// Manages hero sprite assets from the Asset catalog
enum HeroAssetCatalog {

    /// Asset naming convention:
    /// hero_{class}_{tier}
    /// e.g., hero_warrior_apprentice, hero_mage_champion

    static func sprite(for heroClass: HeroClass, tier: EvolutionTier) -> Image? {
        let assetName = "hero_\(heroClass.rawValue)_\(tier.rawValue)"

        // Check if asset exists
        #if os(iOS)
        if UIImage(named: assetName) != nil {
            return Image(assetName)
        }
        #elseif os(macOS)
        if NSImage(named: assetName) != nil {
            return Image(assetName)
        }
        #endif

        // Try generic class sprite (without tier)
        let genericName = "hero_\(heroClass.rawValue)"
        #if os(iOS)
        if UIImage(named: genericName) != nil {
            return Image(genericName)
        }
        #elseif os(macOS)
        if NSImage(named: genericName) != nil {
            return Image(genericName)
        }
        #endif

        return nil
    }

    /// Check if we have real assets or using fallback
    static var hasRealAssets: Bool {
        #if os(iOS)
        return UIImage(named: "hero_warrior") != nil || UIImage(named: "hero_warrior_apprentice") != nil
        #elseif os(macOS)
        return NSImage(named: "hero_warrior") != nil || NSImage(named: "hero_warrior_apprentice") != nil
        #else
        return false
        #endif
    }
}

// MARK: - Asset Setup Instructions

/*
 HOW TO ADD SPRITE ASSETS:

 1. Open Assets.xcassets in Xcode

 2. Create a new Image Set for each hero class/tier:
    - Right-click → New Image Set
    - Name it using convention: hero_{class}_{tier}

    Examples:
    - hero_warrior_apprentice
    - hero_warrior_adventurer
    - hero_warrior_champion
    - hero_warrior_hero
    - hero_warrior_legend
    - hero_mage_apprentice
    - hero_rogue_apprentice
    etc.

    OR use generic names (same sprite for all tiers):
    - hero_warrior
    - hero_mage
    - hero_rogue
    - hero_paladin
    - hero_sage
    - hero_shadow

 3. Add your PNG sprites:
    - Drag PNG files into the image set
    - Use @2x and @3x versions for best quality:
      - 1x: ~64x64 pixels
      - 2x: ~128x128 pixels
      - 3x: ~192x192 pixels
    - Enable "Preserve Vector Data" if using PDFs
    - Set "Render As" to "Original Image" to preserve colors

 4. For the sprite sheet shown:
    - Each character is roughly 96x96 pixels
    - Cut out individual characters from the sheet
    - Save as PNG with transparency
    - Name according to the convention above

 SPRITE SHEET CUTTING GUIDE (for the shared image):

 Row 1:
   - Col 1: Could be Sage (mage with staff)
   - Col 2: Could be Warrior (red armor, axe)
   - Col 3: Could be Paladin (blue knight)
   - Col 4: Could be Rogue (green tunic, sword)

 Row 2:
   - Col 1: Could be Shadow (red cloak, dark)
   - Col 2: Alternative Warrior (purple hair, big sword)
   - Col 3: Could be Mage (witch hat)
   - Col 4: Alternative Rogue (pink, nimble)

 Row 3:
   - Alternative characters for variety

 Row 4:
   - Alternative characters for variety

 RECOMMENDED SELECTIONS:
   - Warrior: Row 1 Col 2 (red armor) or Row 2 Col 2 (purple swordsman)
   - Mage: Row 2 Col 3 (witch) or Row 4 Col 2 (blue mage)
   - Rogue: Row 1 Col 4 (green) or Row 2 Col 4 (pink ninja)
   - Paladin: Row 1 Col 3 (blue knight)
   - Sage: Row 1 Col 1 (staff mage) or Row 4 Col 2 (blue mage)
   - Shadow: Row 2 Col 1 (red cloak) or Row 3 Col 3 (skeleton)
*/

// MARK: - Updated Hero Display using Asset System

/// Hero display that prefers real assets over procedural
struct HeroAssetDisplayView: View {
    let hero: FocusHero
    var size: CGFloat = 120
    var showBackground: Bool = true
    var animated: Bool = true

    @State private var glowOpacity: Double = 0.5
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Background glow
            if showBackground {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                hero.heroClass.primaryColor.opacity(0.35),
                                hero.heroClass.primaryColor.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.5
                        )
                    )
                    .frame(width: size, height: size)
                    .scaleEffect(pulseScale)
            }

            // Ground shadow
            Ellipse()
                .fill(Color.black.opacity(0.35))
                .frame(width: size * 0.5, height: size * 0.12)
                .offset(y: size * 0.35)
                .blur(radius: 4)

            // Hero sprite (prefers assets, falls back to procedural)
            HeroSpriteView(
                heroClass: hero.heroClass,
                tier: hero.evolutionTier,
                size: size * 0.85,
                animated: animated
            )

            // Tier effects for higher tiers
            if hero.evolutionTier >= .champion {
                tierEffects
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.8
                }
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    pulseScale = 1.08
                }
            }
        }
    }

    @ViewBuilder
    private var tierEffects: some View {
        // Outer glow ring
        Circle()
            .stroke(
                hero.heroClass.primaryColor.opacity(0.3),
                lineWidth: hero.evolutionTier == .legend ? 2.5 : 1.5
            )
            .frame(width: size * 0.9, height: size * 0.9)
            .blur(radius: 3)
            .opacity(glowOpacity * 0.7)

        // Legend sparkles
        if hero.evolutionTier == .legend {
            ForEach(0..<4, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.06))
                    .foregroundStyle(.white)
                    .offset(
                        x: cos(Double(i) * .pi / 2 + .pi / 4) * size * 0.45,
                        y: sin(Double(i) * .pi / 2 + .pi / 4) * size * 0.45
                    )
                    .opacity(glowOpacity)
            }
        }
    }
}

// MARK: - Compact Hero for Cards

struct CompactHeroView: View {
    let hero: FocusHero
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            // Subtle glow
            Circle()
                .fill(hero.heroClass.primaryColor.opacity(0.2))
                .frame(width: size, height: size)

            // Sprite
            HeroSpriteView(
                heroClass: hero.heroClass,
                tier: hero.evolutionTier,
                size: size * 0.8,
                animated: true
            )
        }
    }
}

// MARK: - Preview

#Preview("Hero Sprites") {
    ScrollView {
        VStack(spacing: 30) {
            Text("Hero Asset System")
                .font(.headline)
                .foregroundStyle(.white)

            Text(HeroAssetCatalog.hasRealAssets ? "Using real assets" : "Using procedural fallback")
                .font(.caption)
                .foregroundStyle(.gray)

            // All classes
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(HeroClass.allCases, id: \.self) { heroClass in
                    VStack(spacing: 8) {
                        HeroAssetDisplayView(
                            hero: FocusHero(
                                name: heroClass.displayName,
                                heroClass: heroClass,
                                currentLevel: 30,
                                currentXP: 5000
                            ),
                            size: 100
                        )

                        Text(heroClass.displayName)
                            .font(.caption)
                            .foregroundStyle(heroClass.primaryColor)
                    }
                }
            }
            .padding()

            // Evolution preview
            Text("Evolution Tiers")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top)

            HStack(spacing: 12) {
                ForEach(EvolutionTier.allCases, id: \.self) { tier in
                    VStack(spacing: 4) {
                        HeroSpriteView(
                            heroClass: .warrior,
                            tier: tier,
                            size: 50,
                            animated: tier == .legend
                        )

                        Text(tier.displayName)
                            .font(.system(size: 9))
                            .foregroundStyle(tier.badgeColor)
                    }
                }
            }
        }
        .padding()
    }
    .background(Color.black)
}
