import SwiftUI

/// Circular progress indicator for timer display
struct CircularProgress: View {
    let progress: Double
    var lineWidth: CGFloat = 12
    var size: CGFloat = 200

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            DesignSystem.Colors.accent,
                            DesignSystem.Colors.accent.opacity(0.8),
                            Color.purple.opacity(0.7)
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(DesignSystem.Animation.smooth, value: progress)

            // Glow effect when active
            if progress > 0 && progress < 1 {
                Circle()
                    .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        DesignSystem.Colors.accent,
                        style: StrokeStyle(lineWidth: lineWidth * 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 10)
                    .opacity(0.3)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Compact circular progress for list items
struct CompactCircularProgress: View {
    let progress: Double
    var size: CGFloat = 24
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    DesignSystem.Colors.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 40) {
        CircularProgress(progress: 0.65)

        HStack(spacing: 20) {
            CompactCircularProgress(progress: 0.25)
            CompactCircularProgress(progress: 0.50)
            CompactCircularProgress(progress: 0.75)
            CompactCircularProgress(progress: 1.0)
        }
    }
    .padding()
}
