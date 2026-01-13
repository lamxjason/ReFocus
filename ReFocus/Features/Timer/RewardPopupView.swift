import SwiftUI

/// Displays a celebratory popup when user earns a bonus reward
struct RewardPopupView: View {
    let reward: RewardManager.SessionReward
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showIcon = false
    @State private var showParticles = false

    var body: some View {
        ZStack {
            // Dark backdrop
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            // Particle effects
            if showParticles {
                ParticleEmitterView(color: reward.type.color)
                    .ignoresSafeArea()
            }

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Reward icon with animation
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(reward.type.color.opacity(0.3))
                        .frame(width: 160, height: 160)
                        .blur(radius: 30)
                        .scaleEffect(showIcon ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showIcon)

                    // Icon background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [reward.type.color, reward.type.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: reward.type.color.opacity(0.5), radius: 20)

                    // Icon
                    Image(systemName: reward.type.icon)
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(showIcon ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showIcon)

                // Reward title
                Text(reward.type.displayName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                // Reward message
                Text(reward.message)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)

                // XP value if applicable
                if let xp = reward.value, reward.type == .xpBonus {
                    Text("+\(xp) XP")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .yellow.opacity(0.5), radius: 10)
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.5)
                }

                Spacer()

                // Claim button
                Button(action: onDismiss) {
                    Text("Claim Reward")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            LinearGradient(
                                colors: [reward.type.color, reward.type.color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                        .shadow(color: reward.type.color.opacity(0.4), radius: 15)
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xxl)
                .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                showParticles = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                showIcon = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                showContent = true
            }
        }
    }
}

// MARK: - Particle Emitter

struct ParticleEmitterView: View {
    let color: Color
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var opacity: Double
        var rotation: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Image(systemName: "sparkle")
                        .font(.system(size: 12))
                        .foregroundStyle(color)
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                generateParticles(in: geo.size)
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        for _ in 0..<30 {
            let particle = Particle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                scale: CGFloat.random(in: 0.3...1.0),
                opacity: Double.random(in: 0.3...0.8),
                rotation: Double.random(in: 0...360)
            )
            particles.append(particle)
        }

        // Animate particles
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            for i in particles.indices {
                particles[i].y -= CGFloat.random(in: 20...50)
                particles[i].opacity = Double.random(in: 0.2...0.6)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    RewardPopupView(
        reward: RewardManager.SessionReward(
            type: .xpBonus,
            value: 75,
            message: "Bonus XP earned! +75 XP"
        ),
        onDismiss: {}
    )
}

#Preview("Streak Freeze") {
    RewardPopupView(
        reward: RewardManager.SessionReward(
            type: .streakFreeze,
            value: 1,
            message: "Streak Freeze earned! Your streak is protected for one day."
        ),
        onDismiss: {}
    )
}
#endif
