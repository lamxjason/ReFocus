import SwiftUI

/// Delay screen shown when user tries to end a focus session
/// Shows motivational quotes to encourage them to continue
struct EndSessionDelayView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    var modeColor: Color = DesignSystem.Colors.accent

    @State private var currentQuote: Quote = MotivationalQuotes.randomForDelay()
    @State private var countdown: Int = 10
    @State private var canEnd = false
    @State private var quoteOpacity: Double = 1.0

    private let delaySeconds = 10
    private let quoteChangeInterval: TimeInterval = 3

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // Question
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 56, weight: .thin))
                        .foregroundStyle(modeColor)

                    Text("Are you sure?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Text("Take a moment to reflect on why you started this session.")
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                Spacer()

                // Quote - fixed height container to prevent layout shifts
                ZStack {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text(currentQuote.text)
                            .font(.system(size: 18, weight: .medium, design: .serif))
                            .italic()
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)

                        if let author = currentQuote.author {
                            Text("— \(author)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .opacity(quoteOpacity)
                }
                .frame(height: 120)

                Spacer()

                // Countdown or buttons
                VStack(spacing: DesignSystem.Spacing.lg) {
                    if canEnd {
                        Button {
                            onConfirm()
                        } label: {
                            Text("End Session Anyway")
                        }
                        .buttonStyle(.destructive)

                        Button {
                            onCancel()
                        } label: {
                            Text("Keep Focusing")
                        }
                        .buttonStyle(ColoredPrimaryButtonStyle(color: modeColor))
                    } else {
                        // Single countdown ring
                        ZStack {
                            Circle()
                                .stroke(DesignSystem.Colors.backgroundCard, lineWidth: 3)
                                .frame(width: 80, height: 80)

                            Circle()
                                .trim(from: 0, to: CGFloat(delaySeconds - countdown) / CGFloat(delaySeconds))
                                .stroke(modeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: countdown)

                            Text("\(countdown)")
                                .font(.system(size: 28, weight: .light, design: .rounded))
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                .monospacedDigit()
                        }

                        Button {
                            onCancel()
                        } label: {
                            Text("Keep Focusing")
                        }
                        .buttonStyle(ColoredPrimaryButtonStyle(color: modeColor))
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
        }
        .onAppear {
            startCountdown()
            startQuoteRotation()
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
        #endif
    }

    private func startCountdown() {
        Task { @MainActor in
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                countdown -= 1
            }
            withAnimation {
                canEnd = true
            }
        }
    }

    private func startQuoteRotation() {
        Task { @MainActor in
            while !canEnd {
                try? await Task.sleep(for: .seconds(quoteChangeInterval))
                guard !canEnd else { break }

                // Smooth fade out
                withAnimation(.easeInOut(duration: 0.4)) {
                    quoteOpacity = 0
                }

                try? await Task.sleep(for: .milliseconds(400))
                currentQuote = MotivationalQuotes.randomForDelay()

                // Smooth fade in
                withAnimation(.easeInOut(duration: 0.4)) {
                    quoteOpacity = 1
                }
            }
        }
    }
}

#Preview {
    EndSessionDelayView {
        print("Confirmed end")
    } onCancel: {
        print("Cancelled")
    }
}
