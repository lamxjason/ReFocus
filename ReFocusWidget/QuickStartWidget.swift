import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Quick Start Widget

struct QuickStartWidget: Widget {
    let kind: String = "QuickStartWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickStartProvider()) { entry in
            QuickStartWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Focus")
        .description("Start a focus session with one tap")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Provider

struct QuickStartProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickStartEntry {
        QuickStartEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickStartEntry) -> Void) {
        let entry = QuickStartEntry(date: Date(), data: WidgetData.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickStartEntry>) -> Void) {
        let entry = QuickStartEntry(date: Date(), data: WidgetData.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct QuickStartEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Views

struct QuickStartWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: QuickStartEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Small Widget

    private var smallView: some View {
        VStack(spacing: 12) {
            if entry.data.isSessionActive {
                // Active session - show status
                Image(systemName: "brain.head.profile")
                    .font(.title)
                    .foregroundStyle(.green)
                
                Text("Focusing...")
                    .font(.headline)
                
                if let endTime = entry.data.sessionEndTime {
                    Text(endTime, style: .timer)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.green)
                }
            } else {
                // Quick start button
                Link(destination: URL(string: "refocus://start?duration=25")!) {
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.widgetAccent)
                        
                        Text("Start Focus")
                            .font(.headline)
                        
                        Text("25 min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        HStack(spacing: 16) {
            if entry.data.isSessionActive {
                // Active session status
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    
                    Text("Focusing")
                        .font(.headline)
                    
                    if let endTime = entry.data.sessionEndTime {
                        Text(endTime, style: .timer)
                            .font(.system(.title2, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                // Duration options
                ForEach([15, 25, 45, 60], id: \.self) { duration in
                    Link(destination: URL(string: "refocus://start?duration=\(duration)")!) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.widgetAccent.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "play.fill")
                                    .foregroundStyle(Color.widgetAccent)
                            }
                            
                            Text("\(duration)")
                                .font(.headline)
                            
                            Text("min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    QuickStartWidget()
} timeline: {
    QuickStartEntry(date: .now, data: .placeholder)
}

#Preview(as: .systemMedium) {
    QuickStartWidget()
} timeline: {
    QuickStartEntry(date: .now, data: .placeholder)
}
