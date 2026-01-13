import SwiftUI

/// Displays a celebratory popup when user unlocks an achievement
struct AchievementPopupView: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showBadge = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Dark backdrop
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            // Confetti effect
            ConfettiView()
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Achievement unlocked header
                Text("ACHIEVEMENT UNLOCKED")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(4)
                    .opacity(showContent ? 1 : 0)

                // Badge with animation
                ZStack {
                    // Rotating glow
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [.yellow, .orange, .yellow, .white, .yellow],
                                center: .center
                            )
                        )
                        .frame(width: 180, height: 180)
                        .blur(radius: 30)
                        .opacity(0.5)
                        .rotationEffect(.degrees(rotation))

                    // Badge background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.2), Color(white: 0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                        .shadow(color: .yellow.opacity(0.3), radius: 20)

                    // Icon
                    Image(systemName: achievement.icon)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(showBadge ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showBadge)

                // Achievement name
                Text(achievement.name)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(showContent ? 1 : 0)

                // Description
                Text(achievement.description)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(showContent ? 1 : 0)

                // XP reward
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("+\(achievement.xpReward) XP")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                }
                .padding(.top, DesignSystem.Spacing.md)
                .opacity(showContent ? 1 : 0)

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
                                colors: [.yellow, .orange],
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
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                showBadge = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                showContent = true
            }
            // Start rotation animation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var confetti: [ConfettiPiece] = []

    struct ConfettiPiece: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var color: Color
        var rotation: Double
        var scale: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(confetti) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: 8, height: 12)
                        .scaleEffect(piece.scale)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(x: piece.x, y: piece.y)
                }
            }
            .onAppear {
                generateConfetti(in: geo.size)
            }
        }
    }

    private func generateConfetti(in size: CGSize) {
        let colors: [Color] = [.yellow, .orange, .red, .pink, .purple, .blue, .green]

        for _ in 0..<50 {
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 0...size.width),
                y: -20,
                color: colors.randomElement() ?? .yellow,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.5)
            )
            confetti.append(piece)
        }

        // Animate falling
        for i in confetti.indices {
            withAnimation(.easeIn(duration: Double.random(in: 2...4)).delay(Double.random(in: 0...0.5))) {
                confetti[i].y = size.height + 50
                confetti[i].rotation = Double.random(in: 360...720)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    AchievementPopupView(
        achievement: Achievement.streak7,
        onDismiss: {}
    )
}
#endif
