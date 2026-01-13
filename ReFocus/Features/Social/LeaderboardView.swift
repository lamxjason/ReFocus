import SwiftUI

struct LeaderboardView: View {
    @StateObject private var socialManager = SocialManager.shared
    @State private var selectedTimeFrame: LeaderboardTimeFrame = .weekly
    
    var body: some View {
        VStack(spacing: 0) {
            // Time frame picker
            Picker("Time Frame", selection: $selectedTimeFrame) {
                ForEach(LeaderboardTimeFrame.allCases, id: \.self) { frame in
                    Text(frame.rawValue).tag(frame)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            if socialManager.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if socialManager.leaderboard.isEmpty {
                emptyState
            } else {
                leaderboardList
            }
        }
        .navigationTitle("Leaderboard")
        .task {
            await socialManager.fetchLeaderboard()
        }
        .onChange(of: selectedTimeFrame) { _, newValue in
            socialManager.selectedTimeFrame = newValue
            Task {
                await socialManager.fetchLeaderboard()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No leaderboard data yet")
                .font(.headline)
            Text("Complete focus sessions to appear on the leaderboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // Top 3 podium
                if socialManager.leaderboard.count >= 3 {
                    podiumView
                        .padding(.bottom, 16)
                }
                
                // Rest of the list
                ForEach(socialManager.leaderboard.dropFirst(3)) { entry in
                    LeaderboardRowView(entry: entry)
                }
            }
            .padding()
        }
    }
    
    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if socialManager.leaderboard.count > 1 {
                PodiumItemView(entry: socialManager.leaderboard[1], place: 2, height: 100)
            }
            if socialManager.leaderboard.count > 0 {
                PodiumItemView(entry: socialManager.leaderboard[0], place: 1, height: 130)
            }
            if socialManager.leaderboard.count > 2 {
                PodiumItemView(entry: socialManager.leaderboard[2], place: 3, height: 80)
            }
        }
    }
}

struct PodiumItemView: View {
    let entry: LeaderboardEntry
    let place: Int
    let height: CGFloat
    
    private var medal: String {
        switch place {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }
    
    private var podiumColor: Color {
        switch place {
        case 1: return .yellow.opacity(0.3)
        case 2: return .gray.opacity(0.3)
        case 3: return .orange.opacity(0.3)
        default: return .clear
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar
            Circle()
                .fill(entry.isCurrentUser ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(entry.username.prefix(1).uppercased())
                        .font(.title2.bold())
                        .foregroundStyle(entry.isCurrentUser ? .primary : .secondary)
                }
            
            Text(entry.username)
                .font(.caption.bold())
                .lineLimit(1)
            
            Text(entry.focusTimeFormatted)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            // Podium
            RoundedRectangle(cornerRadius: 8)
                .fill(podiumColor)
                .frame(height: height)
                .overlay(alignment: .top) {
                    Text(medal)
                        .font(.title)
                        .padding(.top, 8)
                }
        }
        .frame(maxWidth: .infinity)
    }
}

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(entry.rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40)
            
            // Avatar
            Circle()
                .fill(entry.isCurrentUser ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(entry.username.prefix(1).uppercased())
                        .font(.headline)
                }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username)
                    .font(.headline)
                    .foregroundStyle(entry.isCurrentUser ? .primary : .primary)
                
                HStack(spacing: 8) {
                    Label("Lv.\(entry.level)", systemImage: "star.fill")
                    Label("\(entry.currentStreak)d", systemImage: "flame.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Focus time
            Text(entry.focusTimeFormatted)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Color.accentColor)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(entry.isCurrentUser ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
        }
    }
}

#Preview {
    NavigationStack {
        LeaderboardView()
    }
}
