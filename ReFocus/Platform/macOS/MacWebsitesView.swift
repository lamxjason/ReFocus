import SwiftUI

#if os(macOS)
struct MacWebsitesView: View {
    @EnvironmentObject var websiteSyncManager: WebsiteSyncManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var newWebsite = ""
    @State private var searchText = ""
    @FocusState private var isInputFocused: Bool

    var filteredWebsites: [BlockedWebsite] {
        if searchText.isEmpty {
            return websiteSyncManager.blockedWebsites
        }
        return websiteSyncManager.blockedWebsites.filter {
            $0.domain.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Add website bar
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .frame(width: 24)

                    TextField("Add website (e.g., twitter.com)", text: $newWebsite)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(AppTheme.textPrimary)
                        .focused($isInputFocused)
                        .onSubmit {
                            addWebsite()
                        }

                    if !newWebsite.isEmpty {
                        Button {
                            addWebsite()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(DesignSystem.Colors.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(AppTheme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .strokeBorder(
                            isInputFocused ? DesignSystem.Colors.accent.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.md)

                // Website list
                if websiteSyncManager.blockedWebsites.isEmpty {
                    Spacer()
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "globe")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.textMuted)

                        Text("No Blocked Websites")
                            .font(DesignSystem.Typography.headline)
                            .foregroundStyle(AppTheme.textSecondary)

                        Text("Add websites above to block them during focus sessions.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(AppTheme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(DesignSystem.Spacing.xl)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredWebsites) { website in
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    WebsiteFavicon(domain: website.domain, size: 32)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(website.domain)
                                            .font(DesignSystem.Typography.body)
                                            .foregroundStyle(AppTheme.textPrimary)

                                        Text("Added \(website.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundStyle(AppTheme.textMuted)
                                    }

                                    Spacer()

                                    Button {
                                        removeWebsite(website)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(AppTheme.textMuted)
                                }
                                .padding(DesignSystem.Spacing.md)
                                .background(AppTheme.cardBackground)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                        .padding(DesignSystem.Spacing.md)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search websites")
        .navigationTitle("Websites")
        .toolbar {
            ToolbarItem {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    if websiteSyncManager.isConnected {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.success)
                    }

                    Text("\(websiteSyncManager.blockedWebsites.count) blocked")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private func addWebsite() {
        let domain = cleanDomain(newWebsite)
        guard !domain.isEmpty else {
            newWebsite = ""
            return
        }

        // Check for duplicates
        guard !websiteSyncManager.blockedWebsites.contains(where: { $0.domain == domain }) else {
            newWebsite = ""
            return
        }

        // Add locally first for immediate feedback
        websiteSyncManager.addWebsiteLocal(domain)

        // Clear input but keep focus
        newWebsite = ""

        // Restore focus after a brief delay to allow UI to settle
        // Using multiple attempts to ensure focus stays
        Task { @MainActor in
            // First attempt - quick
            try? await Task.sleep(for: .milliseconds(50))
            isInputFocused = true

            // Second attempt - after UI update cycle
            try? await Task.sleep(for: .milliseconds(100))
            if !isInputFocused {
                isInputFocused = true
            }
        }

        // Try to sync if authenticated
        if supabaseManager.isAuthenticated {
            Task {
                try? await websiteSyncManager.addWebsite(domain)
            }
        }
    }

    private func cleanDomain(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func removeWebsite(_ website: BlockedWebsite) {
        // Use local storage method for immediate feedback
        websiteSyncManager.removeWebsiteLocal(website)

        // Try to sync if authenticated
        if supabaseManager.isAuthenticated {
            Task {
                try? await websiteSyncManager.removeWebsite(website)
            }
        }
    }
}

#Preview {
    MacWebsitesView()
        .environmentObject(WebsiteSyncManager.shared)
        .environmentObject(SupabaseManager.shared)
        .frame(width: 600, height: 400)
}
#endif
