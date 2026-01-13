import SwiftUI

/// Website favicon that fetches real icons with letter fallback
struct WebsiteFavicon: View {
    let domain: String
    var size: CGFloat = 32
    /// Use compact style for stacked displays (circular, no white bg)
    var style: FaviconStyle = .standard

    enum FaviconStyle {
        case standard   // For list rows - white bg, rounded rect
        case compact    // For stacked previews - circular, dark bg with border
    }

    private var faviconURL: URL? {
        // Use Google's favicon service for reliable icons
        URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=128")
    }

    private var letter: String {
        let cleanDomain = domain
            .replacingOccurrences(of: "www.", with: "")
            .uppercased()
        return String(cleanDomain.prefix(1))
    }

    private var fallbackColor: Color {
        let hash = abs(domain.hashValue)
        let colors: [Color] = [
            Color(hex: "4A9C8C"),  // Teal
            Color(hex: "8B5CF6"),  // Purple
            Color(hex: "F97316"),  // Orange
            Color(hex: "3B82F6"),  // Blue
            Color(hex: "84CC16"),  // Lime
            Color(hex: "EC4899"),  // Pink
            Color(hex: "14B8A6"),  // Cyan
            Color(hex: "F59E0B"),  // Amber
        ]
        return colors[hash % colors.count]
    }

    var body: some View {
        AsyncImage(url: faviconURL) { phase in
            switch phase {
            case .success(let image):
                if style == .compact {
                    // Compact: circular with dark background
                    Circle()
                        .fill(AppTheme.elevatedBackground)
                        .frame(width: size, height: size)
                        .overlay {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: size * 0.6, height: size * 0.6)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(AppTheme.border, lineWidth: 1.5)
                        }
                } else {
                    // Standard: rounded rect with white background
                    ZStack {
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .fill(Color.white)

                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size * 0.7, height: size * 0.7)
                    }
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    }
                }

            case .failure, .empty:
                // Letter fallback
                if style == .compact {
                    Circle()
                        .fill(fallbackColor.opacity(0.2))
                        .frame(width: size, height: size)
                        .overlay {
                            Text(letter)
                                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                                .foregroundStyle(fallbackColor)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(fallbackColor.opacity(0.4), lineWidth: 1.5)
                        }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .fill(fallbackColor.opacity(0.15))

                        Text(letter)
                            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                            .foregroundStyle(fallbackColor)
                    }
                    .frame(width: size, height: size)
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .strokeBorder(fallbackColor.opacity(0.3), lineWidth: 1)
                    }
                }

            @unknown default:
                EmptyView()
            }
        }
        .frame(width: size, height: size)
    }
}

/// Website row component for consistent list display
struct WebsiteRow: View {
    let domain: String
    var showDate: Bool = false
    var dateAdded: Date? = nil
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            WebsiteFavicon(domain: domain, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(domain)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(AppTheme.textPrimary)

                if showDate, let date = dateAdded {
                    Text("Added \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(AppTheme.textMuted)
                }
            }

            Spacer()

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.md)
        .background(AppTheme.cardBackground)
    }
}

/// Continuous website input field
struct WebsiteInputField: View {
    @Binding var websites: [String]
    var placeholder: String = "Add website (e.g., youtube.com)"
    var accentColor: Color = DesignSystem.Colors.accent

    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "globe")
                .font(.system(size: 16))
                .foregroundStyle(accentColor)
                .frame(width: 24)

            TextField(placeholder, text: $inputText)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(AppTheme.textPrimary)
                .focused($isFocused)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
                .autocorrectionDisabled()
                .onSubmit {
                    addWebsite()
                }

            if !inputText.isEmpty {
                Button {
                    addWebsite()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(AppTheme.cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(
                    isFocused ? accentColor.opacity(0.5) : AppTheme.border,
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    private func addWebsite() {
        let domain = cleanDomain(inputText)
        guard !domain.isEmpty, !websites.contains(domain) else {
            inputText = ""
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            websites.append(domain)
        }

        // Clear input but keep focus for continuous adding
        inputText = ""
        // Small delay to ensure keyboard stays up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
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
}

#Preview("Favicons") {
    ZStack {
        AppTheme.background.ignoresSafeArea()

        VStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                WebsiteFavicon(domain: "youtube.com")
                WebsiteFavicon(domain: "instagram.com")
                WebsiteFavicon(domain: "youtube.com")
                WebsiteFavicon(domain: "reddit.com")
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                WebsiteFavicon(domain: "facebook.com", size: 24)
                WebsiteFavicon(domain: "tiktok.com", size: 24)
                WebsiteFavicon(domain: "netflix.com", size: 24)
                WebsiteFavicon(domain: "amazon.com", size: 24)
            }

            VStack(spacing: 1) {
                WebsiteRow(domain: "youtube.com", showDate: true, dateAdded: Date()) {}
                WebsiteRow(domain: "instagram.com", showDate: true, dateAdded: Date()) {}
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}
