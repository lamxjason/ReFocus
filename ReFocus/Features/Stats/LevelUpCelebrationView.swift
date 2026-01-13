import SwiftUI

/// Celebratory full-screen view when user levels up
struct LevelUpCelebrationView: View {
    let newLevel: Int
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showLevel = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var ringRotation: Double = 0

    private var levelTitle: String {
        switch newLevel {
        case 1...5: return "Beginner"
        case 6...10: return "Focused"
        case 11...20: return "Dedicated"
        case 21...35: return "Master"
        case 36...50: return "Expert"
        case 51...75: return "Legend"
        case 76...100: return "Grandmaster"
        default: return "Transcendent"
        }
    }

    private var levelColor: Color {
        switch newLevel {
        case 1...5: return .gray
        case 6...10: return .green
        case 11...20: return .blue
        case 21...35: return .purple
        case 36...50: return .orange
        case 51...75: return .red
        case 76...100: return .yellow
        default: return .white
        }
    }

    var body: some View {
        ZStack {
            // Dark backdrop with radial gradient
            RadialGradient(
                colors: [levelColor.opacity(0.3), Color.black],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            // Animated rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        levelColor.opacity(0.3 - Double(index) * 0.1),
                        lineWidth: 2
                    )
                    .frame(width: CGFloat(200 + index * 60), height: CGFloat(200 + index * 60))
                    .rotationEffect(.degrees(ringRotation + Double(index * 30)))
            }

            // Particle burst
            LevelUpParticles(color: levelColor)
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Level up header
                Text("LEVEL UP!")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(levelColor)
                    .tracking(6)
                    .opacity(showContent ? 1 : 0)

                // Level badge
                ZStack {
                    // Glowing circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [levelColor, levelColor.opacity(0.3)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)
                        .scaleEffect(pulseScale)

                    // Main badge
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.15), Color(white: 0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [levelColor, levelColor.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                        .shadow(color: levelColor.opacity(0.5), radius: 20)

                    // Level number
                    VStack(spacing: 0) {
                        Text("\(newLevel)")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, levelColor],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                .scaleEffect(showLevel ? 1 : 0)

                // Level title
                Text(levelTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(showContent ? 1 : 0)

                // Subtitle
                Text("Your dedication is paying off!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(showContent ? 1 : 0)

                // XP progress hint
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("\(newLevel * 100) XP to next level")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .opacity(showContent ? 1 : 0)
                .padding(.top, DesignSystem.Spacing.md)

                Spacer()

                // Continue button
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            LinearGradient(
                                colors: [levelColor, levelColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.bottom, DesignSystem.Spacing.xxl)
                .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            // Animate level badge
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                showLevel = true
            }

            // Animate content
            withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                showContent = true
            }

            // Pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }

            // Ring rotation
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
    }
}

// MARK: - Level Up Particles

struct LevelUpParticles: View {
    let color: Color

    @State private var particles: [LevelParticle] = []

    struct LevelParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(color)
                        .frame(width: particle.size, height: particle.size)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                generateParticles(in: geo.size)
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height / 2

        for _ in 0..<40 {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 50...300)

            let particle = LevelParticle(
                x: centerX,
                y: centerY,
                size: CGFloat.random(in: 4...12),
                opacity: 1.0
            )
            particles.append(particle)
        }

        // Animate outward burst
        for i in particles.indices {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 150...350)

            withAnimation(.easeOut(duration: Double.random(in: 1.5...2.5)).delay(Double.random(in: 0...0.3))) {
                particles[i].x = centerX + cos(angle) * distance
                particles[i].y = centerY + sin(angle) * distance
                particles[i].opacity = 0
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Level 5") {
    LevelUpCelebrationView(newLevel: 5, onDismiss: {})
}

#Preview("Level 15") {
    LevelUpCelebrationView(newLevel: 15, onDismiss: {})
}

#Preview("Level 50") {
    LevelUpCelebrationView(newLevel: 50, onDismiss: {})
}
#endif
