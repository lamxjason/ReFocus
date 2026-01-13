import SwiftUI

#if os(macOS)
struct MacWebsitesView: View {
    @EnvironmentObject var websiteSyncManager: WebsiteSyncManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    @StateObject private var networkManager = NetworkExtensionManager.shared
    @State private var newWebsite = ""
    @State private var searchText = ""
    @State private var isAdding = false
    @State private var recentlyAdded: UUID?
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
                // Network extension notice
                networkExtensionNotice
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)

                // Add website input
                addWebsiteSection
                    .padding(DesignSystem.Spacing.lg)

                // Website list
                if websiteSyncManager.blockedWebsites.isEmpty {
                    emptyState
                } else {
                    websiteList
                }
            }
        }
        .navigationTitle("Websites")
        .toolbar {
            ToolbarItem {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if websiteSyncManager.isConnected {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.success)
                    }

                    Text("\(websiteSyncManager.blockedWebsites.count) blocked")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .onAppear {
            // Auto-focus input field
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                isInputFocused = true
            }
        }
    }

    // MARK: - Network Extension Notice

    private var networkExtensionNotice: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: networkManager.isEnabled ? "network.badge.shield.half.filled" : "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(networkManager.isEnabled ? DesignSystem.Colors.success : DesignSystem.Colors.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text(networkManager.isEnabled ? "Website blocking enabled" : "Network extension required")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text(networkManager.isEnabled
                     ? "Websites blocked system-wide"
                     : "Enable in System Settings → Privacy & Security → Network Extensions")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }

            Spacer()

            if !networkManager.isEnabled {
                Button {
                    // Open System Settings
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_NetworkExtension") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Open")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(networkManager.isEnabled
                      ? DesignSystem.Colors.success.opacity(0.1)
                      : DesignSystem.Colors.warning.opacity(0.1))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(
                    networkManager.isEnabled
                        ? DesignSystem.Colors.success.opacity(0.3)
                        : DesignSystem.Colors.warning.opacity(0.3),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Add Website Section

    private var addWebsiteSection: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "globe")
                .font(.system(size: 16))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 24)

            TextField("Add website (e.g., youtube.com)", text: $newWebsite)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .focused($isInputFocused)
                .onSubmit {
                    addWebsiteKeepFocus()
                }

            if !newWebsite.isEmpty {
                Button {
                    addWebsite()
                } label: {
                    if isAdding {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAdding)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.backgroundCard)
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(
                    isInputFocused ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.border,
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Spacer()

            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(DesignSystem.Colors.textMuted)

            Text("No Blocked Websites")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Text("Add websites above to block them during focus sessions.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Website List

    private var websiteList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(filteredWebsites) { website in
                    MacWebsiteRowView(
                        website: website,
                        isNew: recentlyAdded == website.id
                    ) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            deleteWebsite(website)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: websiteSyncManager.blockedWebsites.count)
        }
    }

    // MARK: - Actions

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

        isAdding = true

        // Add locally first for immediate feedback
        let addedWebsite = websiteSyncManager.addWebsiteLocal(domain)

        // Trigger animation for newly added item
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            recentlyAdded = addedWebsite?.id
        }

        // Clear input but keep focus
        newWebsite = ""

        // Restore focus
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            isInputFocused = true
        }

        // Clear the "new" highlight after a moment
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation {
                recentlyAdded = nil
            }
        }

        isAdding = false

        // Try to sync if authenticated
        if supabaseManager.isAuthenticated {
            Task {
                try? await websiteSyncManager.addWebsite(domain)
            }
        }
    }

    private func addWebsiteKeepFocus() {
        let domain = cleanDomain(newWebsite)
        guard !domain.isEmpty else {
            newWebsite = ""
            isInputFocused = true
            return
        }

        // Check for duplicates
        guard !websiteSyncManager.blockedWebsites.contains(where: { $0.domain == domain }) else {
            newWebsite = ""
            isInputFocused = true
            return
        }

        // Add locally for immediate feedback
        let addedWebsite = websiteSyncManager.addWebsiteLocal(domain)

        // Trigger animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            recentlyAdded = addedWebsite?.id
        }

        // Clear and refocus
        newWebsite = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isInputFocused = true
        }

        // Clear highlight
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation {
                recentlyAdded = nil
            }
        }

        // Sync in background
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

    private func deleteWebsite(_ website: BlockedWebsite) {
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

// MARK: - Website Row

struct MacWebsiteRowView: View {
    let website: BlockedWebsite
    var isNew: Bool = false
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Favicon
            WebsiteFavicon(domain: website.domain, size: 40)
                .overlay {
                    if isNew {
                        Circle()
                            .strokeBorder(DesignSystem.Colors.accent, lineWidth: 2)
                    }
                }

            // Domain info
            VStack(alignment: .leading, spacing: 2) {
                Text(website.domain)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Added \(website.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }

            Spacer()

            // Delete button
            Button {
                showingDeleteConfirm = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isHovered ? DesignSystem.Colors.destructive : DesignSystem.Colors.textMuted)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(isNew ? DesignSystem.Colors.accent.opacity(0.1) : DesignSystem.Colors.backgroundCard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(
                    isNew ? DesignSystem.Colors.accent : (isHovered ? DesignSystem.Colors.border : Color.clear),
                    lineWidth: isNew ? 2 : 1
                )
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .confirmationDialog("Remove \(website.domain)?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    MacWebsitesView()
        .environmentObject(WebsiteSyncManager.shared)
        .environmentObject(SupabaseManager.shared)
        .frame(width: 600, height: 500)
}
#endif
