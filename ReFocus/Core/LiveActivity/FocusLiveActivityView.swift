#if os(iOS)
import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Widget Configuration

@available(iOS 16.2, *)
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: context.attributes.focusModeIcon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(context.state.modeName)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.attributes.totalDurationMinutes)m")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.endTime, style: .timer)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)

                        Text(context.state.isPaused ? "Paused" : "Focusing")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        Link(destination: URL(string: "refocus://stop")!) {
                            Label("End", systemImage: "stop.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.red.opacity(0.15), in: Capsule())
                        }

                        Link(destination: URL(string: "refocus://extend?minutes=5")!) {
                            Label("+5 min", systemImage: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.blue.opacity(0.15), in: Capsule())
                        }
                    }
                }
            } compactLeading: {
                // Compact leading - shown when minimized
                Image(systemName: context.attributes.focusModeIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                // Compact trailing - timer countdown
                Text(context.state.endTime, style: .timer)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.cyan)
                    .frame(minWidth: 40)
            } minimal: {
                // Minimal - just an icon when sharing space
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.cyan)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.2, *)
struct LockScreenView: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Focus mode icon
            ZStack {
                Circle()
                    .fill(.cyan.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: context.attributes.focusModeIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.cyan)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.modeName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(context.state.endTime, style: .timer)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: progressPercentage)
                    .stroke(.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.cyan)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var progressPercentage: CGFloat {
        let total = Double(context.attributes.totalDurationMinutes * 60)
        let remaining = Double(context.state.remainingSeconds)
        guard total > 0 else { return 0 }
        return CGFloat(1.0 - (remaining / total))
    }
}
#endif
