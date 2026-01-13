import WidgetKit
import SwiftUI

// MARK: - Focus Status Widget

struct FocusStatusWidget: Widget {
    let kind: String = "FocusStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusStatusProvider()) { entry in
            FocusStatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Focus Status")
        .description("See your current focus session status")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Provider

struct FocusStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusStatusEntry {
        FocusStatusEntry(date: Date(), data: .placeholder, isActive: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusStatusEntry) -> Void) {
        let data = WidgetData.load()
        let entry = FocusStatusEntry(date: Date(), data: data, isActive: data.isSessionActive)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusStatusEntry>) -> Void) {
        let data = WidgetData.load()
        var entries: [FocusStatusEntry] = []
        
        let now = Date()
        let entry = FocusStatusEntry(date: now, data: data, isActive: data.isSessionActive)
        entries.append(entry)
        
        // If session is active, add entry for when it ends
        if data.isSessionActive, let endTime = data.sessionEndTime {
            let endEntry = FocusStatusEntry(
                date: endTime,
                data: WidgetData(
                    currentStreak: data.currentStreak,
                    level: data.level,
                    totalFocusMinutes: data.totalFocusMinutes,
                    isSessionActive: false,
                    sessionEndTime: nil,
                    todayFocusMinutes: data.todayFocusMinutes
                ),
                isActive: false
            )
            entries.append(endEntry)
        }
        
        // Refresh every 5 minutes during active session, 30 minutes otherwise
        let refreshInterval = data.isSessionActive ? 5 : 30
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: refreshInterval, to: now)!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct FocusStatusEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
    let isActive: Bool
}

// MARK: - Views

struct FocusStatusWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: FocusStatusEntry

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
            if entry.isActive {
                // Active session
                Image(systemName: "brain.head.profile")
                    .font(.title)
                    .foregroundStyle(.green)
                
                Text("Focusing")
                    .font(.headline)
                
                if let endTime = entry.data.sessionEndTime {
                    Text(endTime, style: .timer)
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(.green)
                }
            } else {
                // No active session
                Image(systemName: "moon.zzz")
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                Text("Not Focusing")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("\(entry.data.todayFocusMinutes)m today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        HStack(spacing: 20) {
            // Status
            VStack(spacing: 8) {
                if entry.isActive {
                    Image(systemName: "brain.head.profile")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    
                    Text("Focusing")
                        .font(.headline)
                    
                    if let endTime = entry.data.sessionEndTime {
                        Text(endTime, style: .timer)
                            .font(.system(.title, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.widgetAccent)
                    
                    Text("Ready to Focus")
                        .font(.headline)
                    
                    Text("Tap to start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Stats
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(entry.data.currentStreak) day streak")
                }
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("Level \(entry.data.level)")
                }
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.blue)
                    Text("\(entry.data.todayFocusMinutes)m today")
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    FocusStatusWidget()
} timeline: {
    FocusStatusEntry(date: .now, data: .placeholder, isActive: false)
    FocusStatusEntry(date: .now, data: WidgetData(
        currentStreak: 7,
        level: 5,
        totalFocusMinutes: 1200,
        isSessionActive: true,
        sessionEndTime: Date().addingTimeInterval(1500),
        todayFocusMinutes: 45
    ), isActive: true)
}
