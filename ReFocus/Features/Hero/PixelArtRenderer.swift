import SwiftUI

// MARK: - Pixel Art Rendering System

/// Renders pixel art sprites from 2D color arrays
struct PixelArtView: View {
    let pixels: [[Color]]
    let pixelSize: CGFloat
    let animated: Bool

    @State private var breatheOffset: CGFloat = 0
    @State private var bounce: CGFloat = 0

    init(pixels: [[Color]], pixelSize: CGFloat = 4, animated: Bool = false) {
        self.pixels = pixels
        self.pixelSize = pixelSize
        self.animated = animated
    }

    var body: some View {
        Canvas { context, size in
            for (rowIndex, row) in pixels.enumerated() {
                for (colIndex, color) in row.enumerated() {
                    guard color != .clear else { continue }

                    let x = CGFloat(colIndex) * pixelSize
                    // Breathing animation - top half moves slightly
                    let animOffset = animated ? breatheOffset * (rowIndex < 12 ? 1.0 : 0.3) : 0
                    let y = CGFloat(rowIndex) * pixelSize + animOffset

                    let rect = CGRect(x: x, y: y, width: pixelSize + 0.5, height: pixelSize + 0.5)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(
            width: CGFloat(pixels.first?.count ?? 0) * pixelSize,
            height: CGFloat(pixels.count) * pixelSize
        )
        .offset(y: animated ? bounce : 0)
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    breatheOffset = -1.5
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    bounce = -3
                }
            }
        }
    }
}

// MARK: - Hero Sprite Generator (Improved 20x28 sprites)

/// Generates pixel art sprites for heroes based on class and tier
struct HeroSpriteGenerator {

    /// Generate a complete hero sprite
    static func generateSprite(
        heroClass: HeroClass,
        tier: EvolutionTier,
        hasAscended: Bool = false
    ) -> [[Color]] {
        let palette = getPalette(for: heroClass, tier: tier, ascended: hasAscended)
        let baseSprite = getBaseSprite(for: heroClass, tier: tier)

        return baseSprite.map { row in
            row.map { colorKey in
                palette[colorKey] ?? .clear
            }
        }
    }

    // MARK: - Color Palettes

    private static func getPalette(for heroClass: HeroClass, tier: EvolutionTier, ascended: Bool) -> [Character: Color] {
        // Skin tones
        let skin = Color(red: 1.0, green: 0.87, blue: 0.75)
        let skinShade = Color(red: 0.92, green: 0.75, blue: 0.6)
        let skinDark = Color(red: 0.78, green: 0.58, blue: 0.42)

        // Hair colors (warm brown)
        let hair = Color(red: 0.38, green: 0.28, blue: 0.18)
        let hairLight = Color(red: 0.52, green: 0.38, blue: 0.25)
        let hairDark = Color(red: 0.25, green: 0.18, blue: 0.1)

        // Common colors
        let black = Color(red: 0.12, green: 0.1, blue: 0.15)
        let white = Color.white
        let eye = Color(red: 0.18, green: 0.16, blue: 0.22)

        // Class-specific colors with tier brightness
        let (c1, c2, c3, c4) = getClassColors(heroClass, tier: tier, ascended: ascended)

        return [
            ".": .clear,
            "X": .clear,
            " ": .clear,

            // Skin
            "S": skin,
            "s": skinShade,
            "d": skinDark,

            // Hair
            "H": hair,
            "h": hairLight,
            "D": hairDark,

            // Eyes/outline
            "O": black,
            "E": eye,
            "W": white,
            "P": Color(red: 0.2, green: 0.15, blue: 0.1), // Pupil

            // Class colors (primary, secondary, tertiary, accent)
            "1": c1,
            "2": c2,
            "3": c3,
            "4": c4,

            // Highlight (lighter version of primary)
            "L": c1.opacity(0.7).blend(with: .white, amount: 0.3),

            // Metals
            "G": Color(red: 0.98, green: 0.85, blue: 0.45),  // Gold
            "g": Color(red: 0.78, green: 0.65, blue: 0.3),   // Gold shadow
            "M": Color(red: 0.75, green: 0.78, blue: 0.82),  // Metal/Silver
            "m": Color(red: 0.55, green: 0.58, blue: 0.62),  // Metal shadow
            "B": Color(red: 0.65, green: 0.5, blue: 0.35),   // Bronze/Brown
            "b": Color(red: 0.45, green: 0.35, blue: 0.22),  // Bronze shadow
        ]
    }

    private static func getClassColors(_ heroClass: HeroClass, tier: EvolutionTier, ascended: Bool) -> (Color, Color, Color, Color) {
        let brightness = tierBrightness(tier)

        if ascended {
            // Golden ascended colors
            return (
                Color(red: 1.0 * brightness, green: 0.85 * brightness, blue: 0.35),
                Color(red: 0.88 * brightness, green: 0.72 * brightness, blue: 0.25),
                Color(red: 0.75 * brightness, green: 0.58 * brightness, blue: 0.18),
                Color.white
            )
        }

        switch heroClass {
        case .warrior:
            return (
                Color(red: 0.78 * brightness, green: 0.22, blue: 0.22),      // Crimson
                Color(red: 0.58 * brightness, green: 0.15, blue: 0.15),      // Dark red
                Color(red: 0.42 * brightness, green: 0.1, blue: 0.1),        // Darker
                Color(red: 0.95, green: 0.8, blue: 0.4)                      // Gold accent
            )
        case .mage:
            return (
                Color(red: 0.35, green: 0.4, blue: 0.82 * brightness),       // Royal blue
                Color(red: 0.25, green: 0.28, blue: 0.62 * brightness),      // Dark blue
                Color(red: 0.18, green: 0.2, blue: 0.45 * brightness),       // Darker
                Color(red: 0.75, green: 0.55, blue: 0.95)                    // Purple accent
            )
        case .rogue:
            return (
                Color(red: 0.32 * brightness, green: 0.36 * brightness, blue: 0.4 * brightness), // Dark gray
                Color(red: 0.22, green: 0.25, blue: 0.28),                   // Darker
                Color(red: 0.15, green: 0.18, blue: 0.2),                    // Darkest
                Color(red: 0.55, green: 0.85, blue: 0.55)                    // Green accent
            )
        case .paladin:
            return (
                Color(red: 0.95 * brightness, green: 0.92 * brightness, blue: 0.78), // Cream/gold
                Color(red: 0.78 * brightness, green: 0.74 * brightness, blue: 0.55), // Darker
                Color(red: 0.58, green: 0.54, blue: 0.4),                    // Darkest
                Color(red: 0.45, green: 0.65, blue: 0.95)                    // Blue accent
            )
        case .sage:
            return (
                Color(red: 0.55, green: 0.4, blue: 0.68 * brightness),       // Purple
                Color(red: 0.4, green: 0.3, blue: 0.52 * brightness),        // Darker
                Color(red: 0.3, green: 0.22, blue: 0.38),                    // Darkest
                Color(red: 0.95, green: 0.9, blue: 0.65)                     // Cream accent
            )
        case .shadow:
            return (
                Color(red: 0.25, green: 0.2, blue: 0.35 * brightness),       // Dark purple
                Color(red: 0.18, green: 0.12, blue: 0.25),                   // Darker
                Color(red: 0.1, green: 0.08, blue: 0.15),                    // Darkest
                Color(red: 0.65, green: 0.35, blue: 0.85)                    // Purple glow
            )
        }
    }

    private static func tierBrightness(_ tier: EvolutionTier) -> Double {
        switch tier {
        case .apprentice: return 0.88
        case .adventurer: return 0.94
        case .champion: return 1.0
        case .hero: return 1.06
        case .legend: return 1.12
        }
    }

    // MARK: - Sprite Data (20x28 - better proportions)

    private static func getBaseSprite(for heroClass: HeroClass, tier: EvolutionTier) -> [[Character]] {
        switch heroClass {
        case .warrior: return warriorSprite(tier)
        case .mage: return mageSprite(tier)
        case .rogue: return rogueSprite(tier)
        case .paladin: return paladinSprite(tier)
        case .sage: return sageSprite(tier)
        case .shadow: return shadowSprite(tier)
        }
    }

    // MARK: - Warrior (Knight with sword & shield)

    private static func warriorSprite(_ tier: EvolutionTier) -> [[Character]] {
        return [
            Array("...................."),
            Array(".......HHHH........."),
            Array("......HHHHHH........"),
            Array(".....HHHHHHHH......."),
            Array(".....HHHHHHHH......."),
            Array("....HSSSSSSSSH......"),
            Array("....HSSEWWSESH......"),
            Array("....HSSdSSdSsH......"),
            Array(".....SsSSSsSs......."),
            Array("......SdSSdS........"),
            Array(".....M1M11M1M......."),
            Array("....M111GG111M......"),
            Array("...M11111111114G...."),
            Array("..M1111111111144G..."),
            Array("..11111GG111114MG..."),
            Array("..M1111111111MMM...."),
            Array("...111222211........"),
            Array("...111222211........"),
            Array("....11222211........"),
            Array("....22..M.22........"),
            Array("...222..M..222......"),
            Array("...111..M..111......"),
            Array("..1111..M..1111....."),
            Array("..111...M...111....."),
            Array("..111...M...111....."),
            Array("........M..........."),
            Array("........M..........."),
            Array("...................."),
        ]
    }

    // MARK: - Mage (Wizard with staff)

    private static func mageSprite(_ tier: EvolutionTier) -> [[Character]] {
        return [
            Array("...................."),
            Array(".......4444........."),
            Array("......411114........"),
            Array(".....41144114......."),
            Array(".....11144411......."),
            Array(".....SSSSSSSS......."),
            Array("....SSSEWWSESS......"),
            Array("....SSSdSSdSsS......"),
            Array(".....SsSSSsSs......."),
            Array("......SdSSdS........"),
            Array(".....11111111......."),
            Array("....1111441111......"),
            Array("...111144441114....."),
            Array("..1111144411114....."),
            Array("..1111144411111....."),
            Array("...11114441111M....."),
            Array("...111111111MM......"),
            Array("....1111111M........"),
            Array("....11111111........"),
            Array("....11111111........"),
            Array(".....111111........."),
            Array(".....111111........."),
            Array("......1111.........."),
            Array("......1111.........."),
            Array(".......11..........."),
            Array("...................."),
            Array("...................."),
            Array("...................."),
        ]
    }

    // MARK: - Rogue (Hooded assassin with daggers)

    private static func rogueSprite(_ tier: EvolutionTier) -> [[Character]] {
        return [
            Array("...................."),
            Array(".......1111........."),
            Array("......111111........"),
            Array(".....11111111......."),
            Array("....1111111111......"),
            Array("....111SSSS111......"),
            Array("....11SEWWSE11......"),
            Array("....111SSSsS11......"),
            Array(".....11SssSs1......."),
            Array("......1SSS1........."),
            Array(".....11111111......."),
            Array("....1111221111......"),
            Array("...111122221114....."),
            Array("..1111222222114....."),
            Array("..1111222222111....."),
            Array("...11112221111......"),
            Array("....111221114......."),
            Array("....11122111........"),
            Array(".....22..22........."),
            Array("....22....22........"),
            Array("....22....22........"),
            Array("...111...111........"),
            Array("...111...111........"),
            Array("...111...111........"),
            Array("....11...11........."),
            Array("...................."),
            Array("...................."),
            Array("...................."),
        ]
    }

    // MARK: - Paladin (Holy knight with golden accents)

    private static func paladinSprite(_ tier: EvolutionTier) -> [[Character]] {
        return [
            Array("...................."),
            Array(".......GGG.........."),
            Array("......G111G........."),
            Array(".....G11111G........"),
            Array(".....1111111........"),
            Array("....1SSSSSSSS1......"),
            Array("....1SSEWWSES1......"),
            Array("....1SSSSSsSs1......"),
            Array(".....1SsSSsS1......."),
            Array("......SdSSdS........"),
            Array(".....G111111G......."),
            Array("....G11144111G......"),
            Array("...111144441111....."),
            Array("..11111G44G11111...."),
            Array("..111114441111M....."),
            Array("..G111111111GMM....."),
            Array("...11122221111......"),
            Array("....1122221111......"),
            Array(".....12222111......."),
            Array(".....22...22........"),
            Array("....122..221........"),
            Array("...1111.1111........"),
            Array("...1111.1111........"),
            Array("...111...111........"),
            Array("....11...11........."),
            Array("...................."),
            Array("...................."),
            Array("...................."),
        ]
    }

    // MARK: - Sage (Elder wizard with beard)

    private static func sageSprite(_ tier: EvolutionTier) -> [[Character]] {
        return [
            Array("...................."),
            Array(".......1111........."),
            Array("......111111........"),
            Array(".....11111111......."),
            Array(".....SSSSSSSS......."),
            Array("....SSSEWWSESS......"),
            Array("....SSSSSSsSsS......"),
            Array("....SWWWWWWWWS......"),
            Array(".....SWWWWWWS......."),
            Array("......SWWWS........."),
            Array(".....11111111......."),
            Array("....1114444111......"),
            Array("...111444444111....."),
            Array("..1111444444111....."),
            Array("..11114444411111...."),
            Array("...111144411111....."),
            Array("...1111111111M......"),
            Array("....11111111M......."),
            Array("....111111111......."),
            Array(".....11111111......."),
            Array(".....111111111......"),
            Array("......11111111......"),
            Array("......11111111......"),
            Array(".......111111......"),
            Array(".......1111........."),
            Array("...................."),
            Array("...................."),
            Array("...................."),
        ]
    }

    // MARK: - Shadow (Ethereal cloaked figure)

    private static func shadowSprite(_ tier: EvolutionTier) -> [[Character]] {
        return [
            Array("...................."),
            Array(".......1111........."),
            Array("......111111........"),
            Array(".....11111111......."),
            Array("....1111111111......"),
            Array("....1114..4111......"),
            Array("....111....111......"),
            Array(".....111111111......"),
            Array("......111111........"),
            Array(".....1111111........"),
            Array("....11111111111....."),
            Array("...1111122211111...."),
            Array("..111111221111111..."),
            Array("..111111221111111..."),
            Array("..11111111111111...."),
            Array("...11111111111......"),
            Array("....111111111......."),
            Array(".....1111111111....."),
            Array("......111111111....."),
            Array(".......11111111....."),
            Array("........1111111....."),
            Array(".........111111....."),
            Array("..........11111....."),
            Array("...........1111....."),
            Array("............111....."),
            Array("...................."),
            Array("...................."),
            Array("...................."),
        ]
    }
}

// MARK: - Color Blending Extension

extension Color {
    func blend(with color: Color, amount: Double) -> Color {
        // Simple blend approximation
        return self.opacity(1 - amount)
    }
}

// MARK: - Preview

#Preview("Pixel Heroes") {
    ScrollView {
        VStack(spacing: 30) {
            // All classes
            Text("Hero Classes")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 20) {
                ForEach([HeroClass.warrior, .mage, .rogue], id: \.self) { heroClass in
                    VStack {
                        PixelArtView(
                            pixels: HeroSpriteGenerator.generateSprite(
                                heroClass: heroClass,
                                tier: .champion
                            ),
                            pixelSize: 4,
                            animated: true
                        )
                        Text(heroClass.displayName)
                            .font(.caption)
                            .foregroundStyle(heroClass.primaryColor)
                    }
                }
            }

            HStack(spacing: 20) {
                ForEach([HeroClass.paladin, .sage, .shadow], id: \.self) { heroClass in
                    VStack {
                        PixelArtView(
                            pixels: HeroSpriteGenerator.generateSprite(
                                heroClass: heroClass,
                                tier: .champion
                            ),
                            pixelSize: 4,
                            animated: true
                        )
                        Text(heroClass.displayName)
                            .font(.caption)
                            .foregroundStyle(heroClass.primaryColor)
                    }
                }
            }

            // Evolution tiers
            Text("Warrior Evolution")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top)

            HStack(spacing: 12) {
                ForEach(EvolutionTier.allCases, id: \.self) { tier in
                    VStack {
                        PixelArtView(
                            pixels: HeroSpriteGenerator.generateSprite(
                                heroClass: .warrior,
                                tier: tier
                            ),
                            pixelSize: 3,
                            animated: tier == .legend
                        )
                        Text(tier.displayName)
                            .font(.system(size: 9))
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
        .padding()
    }
    .background(Color.black)
}
