import Foundation

/// Represents a blocked website domain synced across all devices
struct BlockedWebsite: Codable, Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let userId: UUID
    let domain: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case domain
        case createdAt = "created_at"
    }

    init(id: UUID = UUID(), userId: UUID, domain: String, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        // Normalize domain: remove protocol, www, and trailing slashes
        self.domain = Self.normalizeDomain(domain)
        self.createdAt = createdAt
    }

    /// Normalizes a domain string by removing protocol, www prefix, and trailing content
    static func normalizeDomain(_ input: String) -> String {
        var domain = input.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")

        // Remove path and query string
        if let slashIndex = domain.firstIndex(of: "/") {
            domain = String(domain[..<slashIndex])
        }

        return domain.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Checks if a given URL host matches this blocked domain
    func matches(host: String) -> Bool {
        let normalizedHost = host.lowercased()
        return normalizedHost == domain || normalizedHost.hasSuffix(".\(domain)")
    }
}

// MARK: - Collection Extensions

extension Collection where Element == BlockedWebsite {
    /// Returns the set of all domain strings
    var domains: Set<String> {
        Set(map { $0.domain })
    }

    /// Checks if any blocked website matches the given host
    func containsMatch(for host: String) -> Bool {
        contains { $0.matches(host: host) }
    }
}
