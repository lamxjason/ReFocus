import SwiftUI

// MARK: - Premium Visual Identity for ReFocus
// "Aurora Flow" - Representing the flow state of deep focus

enum PremiumPalette {
    // Core gradient colors - Aurora spectrum
    static let auroraStart = Color(hex: "667EEA")     // Soft violet
    static let auroraMid = Color(hex: "5B86E5")       // Ocean blue
    static let auroraEnd = Color(hex: "36D1DC")       // Teal cyan

    // Alternative accent gradients for modes
    static let deepWorkStart = Color(hex: "764BA2")   // Deep purple
    static let deepWorkEnd = Color(hex: "667EEA")     // Violet

    static let zenStart = Color(hex: "11998E")        // Teal
    static let zenEnd = Color(hex: "38EF7D")          // Mint green

    static let fireStart = Color(hex: "F2994A")       // Orange
    static let fireEnd = Color(hex: "F2C94C")         // Gold

    // Glow colors
    static let glowPrimary = Color(hex: "667EEA").opacity(0.5)
    static let glowSecondary = Color(hex: "36D1DC").opacity(0.4)

    // Premium gradients
    static var auroraGradient: LinearGradient {
        LinearGradient(
            colors: [auroraStart, auroraMid, auroraEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var auroraVertical: LinearGradient {
        LinearGradient(
            colors: [auroraStart, auroraEnd],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var meshGradient: some View {
        MeshGradientView()
    }
}

// MARK: - Animated Mesh Gradient Background

struct MeshGradientView: View {
    @State private var animate = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                // Create flowing aurora effect
                for i in 0..<3 {
                    let offset = Double(i) * 0.3
                    let x = sin(time * 0.5 + offset) * size.width * 0.3 + size.width * 0.5
                    let y = cos(time * 0.3 + offset) * size.height * 0.2 + size.height * 0.4

                    let gradient = Gradient(colors: [
                        PremiumPalette.auroraStart.opacity(0.3),
                        PremiumPalette.auroraMid.opacity(0.2),
                        PremiumPalette.auroraEnd.opacity(0.1),
                        .clear
                    ])

                    context.drawLayer { ctx in
                        ctx.addFilter(.blur(radius: 60))
                        ctx.fill(
                            Ellipse().path(in: CGRect(
                                x: x - 150,
                                y: y - 100,
                                width: 300,
                                height: 200
                            )),
                            with: .radialGradient(
                                gradient,
                                center: CGPoint(x: x, y: y),
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Signature Focus Orb (Hero Element)

struct FocusOrb: View {
    let progress: Double // 0 to 1
    let isActive: Bool
    var accentColor: Color = PremiumPalette.auroraStart

    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var glowOpacity: Double = 0.5

    var body: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                accentColor.opacity(0.4),
                                PremiumPalette.auroraEnd.opacity(0.2),
                                accentColor.opacity(0.1),
                                .clear,
                                accentColor.opacity(0.4)
                            ],
                            center: .center,
                            startAngle: .degrees(rotationAngle + Double(index * 120)),
                            endAngle: .degrees(rotationAngle + Double(index * 120) + 360)
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 280 + CGFloat(index * 20), height: 280 + CGFloat(index * 20))
                    .opacity(isActive ? 0.6 - Double(index) * 0.15 : 0.2)
                    .blur(radius: CGFloat(index) * 2)
            }

            // Ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentColor.opacity(glowOpacity * 0.3),
                            accentColor.opacity(glowOpacity * 0.1),
                            .clear
                        ],
                        center: .center,
                        startRadius: 80,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .scaleEffect(pulseScale)

            // Progress ring background
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 4)
                .frame(width: 240, height: 240)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [accentColor, PremiumPalette.auroraEnd, accentColor],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))

            // Inner orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "1a1a2e"),
                            Color(hex: "0f0f1a")
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .overlay {
                    // Subtle inner glow
                    Circle()
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                }

            // Glass reflection effect
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: 180, height: 80)
                .offset(y: -50)
                .blur(radius: 2)
        }
        .onAppear {
            if isActive {
                startAnimations()
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                startAnimations()
            } else {
                stopAnimations()
            }
        }
    }

    private func startAnimations() {
        // Pulse animation
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
            glowOpacity = 0.7
        }

        // Rotation animation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }

    private func stopAnimations() {
        withAnimation(.easeOut(duration: 0.5)) {
            pulseScale = 1.0
            glowOpacity = 0.3
        }
    }
}

// MARK: - Glowing Timer Ring

struct GlowingTimerRing: View {
    let progress: Double
    let lineWidth: CGFloat
    var accentColor: Color = PremiumPalette.auroraStart

    var body: some View {
        ZStack {
            // Glow layer
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: lineWidth + 8, lineCap: .round)
                )
                .blur(radius: 8)
                .opacity(0.5)

            // Main ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [accentColor, PremiumPalette.auroraEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
        }
        .rotationEffect(.degrees(-90))
    }
}

// MARK: - Premium Card Style

struct PremiumCardStyle: ViewModifier {
    var accentColor: Color = PremiumPalette.auroraStart

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "0f0f1a"))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        accentColor.opacity(0.3),
                                        accentColor.opacity(0.1),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(color: accentColor.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func premiumCard(accent: Color = PremiumPalette.auroraStart) -> some View {
        modifier(PremiumCardStyle(accentColor: accent))
    }
}

// MARK: - Gradient Text

struct GradientText: View {
    let text: String
    let font: Font
    var gradient: LinearGradient = PremiumPalette.auroraGradient

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(gradient)
    }
}

// MARK: - Animated Gradient Button

struct PremiumButtonStyle: ButtonStyle {
    var gradient: LinearGradient = PremiumPalette.auroraGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(gradient)
                    .shadow(color: PremiumPalette.auroraStart.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Premium Tab Bar Item

struct PremiumTabItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    var accentColor: Color = PremiumPalette.auroraStart

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .blur(radius: 8)
                }

                Image(systemName: isSelected ? "\(icon).fill" : icon)
                    .font(.system(size: 22))
                    .foregroundStyle(
                        isSelected
                            ? accentColor
                            : Color.white.opacity(0.5)
                    )
            }

            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(
                    isSelected
                        ? accentColor
                        : Color.white.opacity(0.5)
                )
        }
    }
}

// MARK: - Particle Effect for Completion

struct CompletionParticles: View {
    @State private var particles: [Particle] = []
    let isActive: Bool
    var accentColor: Color = PremiumPalette.auroraStart

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var opacity: Double
    }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .position(x: particle.x, y: particle.y)
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                spawnParticles()
            }
        }
    }

    private func spawnParticles() {
        for i in 0..<20 {
            let delay = Double(i) * 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let particle = Particle(
                    x: CGFloat.random(in: 100...300),
                    y: 200,
                    scale: CGFloat.random(in: 0.5...1.5),
                    opacity: 1.0
                )
                particles.append(particle)

                // Animate particle
                withAnimation(.easeOut(duration: 1.5)) {
                    if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                        particles[index].y -= CGFloat.random(in: 100...200)
                        particles[index].x += CGFloat.random(in: -50...50)
                        particles[index].opacity = 0
                    }
                }

                // Remove particle
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    particles.removeAll { $0.id == particle.id }
                }
            }
        }
    }
}

// Color(hex:) extension is defined in DesignSystem.swift

#Preview("Focus Orb") {
    ZStack {
        Color.black.ignoresSafeArea()
        FocusOrb(progress: 0.65, isActive: true)
    }
}

#Preview("Premium Button") {
    ZStack {
        Color.black.ignoresSafeArea()
        Button("Start Focus") {}
            .buttonStyle(PremiumButtonStyle())
            .padding()
    }
}
