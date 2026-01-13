import SwiftUI

/// Celebration view shown when hero evolves to a new tier
struct EvolutionCelebrationView: View {
    let hero: FocusHero
    let newTier: EvolutionTier
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showParticles = false
    @State private var ringScale: CGFloat = 0.5
    @State private var heroScale: CGFloat = 0.8
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Animated glow background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            newTier.badgeColor.opacity(glowOpacity * 0.4),
                            newTier.badgeColor.opacity(glowOpacity * 0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .blur(radius: 50)

            // Particle effects
            if showParticles {
                particleField
            }

            // Main content
            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Evolution ring
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(newTier.badgeColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 260, height: 260)
                        .scaleEffect(ringScale)

                    // Inner ring
                    Circle()
                        .stroke(newTier.badgeColor, lineWidth: 3)
                        .frame(width: 220, height: 220)
                        .scaleEffect(ringScale)

                    // Hero
                    HeroDisplayView(
                        hero: hero,
                        size: 180,
                        showBackground: false,
                        animated: true
                    )
                    .scaleEffect(heroScale)
                }

                // Title
                if showContent {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Text("EVOLUTION!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(newTier.badgeColor)
                            .tracking(4)

                        Text(hero.name)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)

                        Text("has become")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        // New tier badge
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: tierIcon)
                                .font(.system(size: 20))

                            Text(newTier.displayName)
                                .font(.system(size: 24, weight: .bold))
                        }
                        .foregroundStyle(newTier.badgeColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background {
                            Capsule()
                                .fill(newTier.badgeColor.opacity(0.2))
                        }

                        // Tier description
                        Text(newTier.description)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .padding(.top, DesignSystem.Spacing.sm)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Continue button
                if showContent {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Continue")
                    }
                    .buttonStyle(ColoredPrimaryButtonStyle(color: newTier.badgeColor))
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Computed

    private var tierIcon: String {
        switch newTier {
        case .apprentice: return "leaf.fill"
        case .adventurer: return "map.fill"
        case .champion: return "shield.fill"
        case .hero: return "star.fill"
        case .legend: return "crown.fill"
        }
    }

    // MARK: - Particles

    private var particleField: some View {
        GeometryReader { geo in
            ForEach(0..<30, id: \.self) { i in
                particle(index: i, size: geo.size)
            }
        }
    }

    private func particle(index: Int, size: CGSize) -> some View {
        let randomX = CGFloat.random(in: 0...size.width)
        let randomDelay = Double.random(in: 0...1)
        let randomDuration = Double.random(in: 2...4)
        let randomSize = CGFloat.random(in: 4...8)

        return Circle()
            .fill(newTier.badgeColor)
            .frame(width: randomSize, height: randomSize)
            .position(x: randomX, y: size.height)
            .modifier(ParticleModifier(
                delay: randomDelay,
                duration: randomDuration,
                targetY: -50
            ))
    }

    // MARK: - Animation

    private func startAnimation() {
        // Ring expansion
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
            ringScale = 1.0
        }

        // Hero scale
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
            heroScale = 1.0
        }

        // Glow
        withAnimation(.easeIn(duration: 0.5).delay(0.2)) {
            glowOpacity = 1.0
        }

        // Particles
        withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
            showParticles = true
        }

        // Content
        withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
            showContent = true
        }
    }
}

// MARK: - Particle Modifier

struct ParticleModifier: ViewModifier {
    let delay: Double
    let duration: Double
    let targetY: CGFloat

    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offsetY)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: duration).delay(delay).repeatForever(autoreverses: false)) {
                    offsetY = targetY - 500
                }
                withAnimation(.easeIn(duration: 0.5).delay(delay)) {
                    opacity = 0.8
                }
                withAnimation(.easeOut(duration: 0.5).delay(delay + duration - 0.5)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Preview

#Preview("Evolution") {
    EvolutionCelebrationView(
        hero: FocusHero(
            name: "Aria",
            heroClass: .mage,
            currentLevel: 26,
            currentXP: 26000
        ),
        newTier: .champion
    ) {
        print("Dismissed")
    }
}
