import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import IOKit
import AppKit
#endif

/// Represents the current device for multi-device tracking
struct DeviceInfo: Codable, Sendable {
    let id: String
    var userId: UUID
    let deviceName: String
    let platform: Platform
    var lastSeenAt: Date

    enum Platform: String, Codable, Sendable {
        case ios
        case macos
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceName = "device_name"
        case platform
        case lastSeenAt = "last_seen_at"
    }

    init(id: String, userId: UUID, deviceName: String, platform: Platform, lastSeenAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.deviceName = deviceName
        self.platform = platform
        self.lastSeenAt = lastSeenAt
    }

    /// Creates a DeviceInfo for the current device
    static func current(userId: UUID) -> DeviceInfo {
        DeviceInfo(
            id: currentDeviceId,
            userId: userId,
            deviceName: currentDeviceName,
            platform: currentPlatform,
            lastSeenAt: Date()
        )
    }

    /// Unique identifier for this device
    static var currentDeviceId: String {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios-\(UUID().uuidString)"
        #elseif os(macOS)
        return macHardwareUUID ?? "unknown-mac-\(UUID().uuidString)"
        #else
        return "unknown-\(UUID().uuidString)"
        #endif
    }

    /// Human-readable device name
    static var currentDeviceName: String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Unknown Device"
        #endif
    }

    /// Current platform
    static var currentPlatform: Platform {
        #if os(iOS)
        return .ios
        #elseif os(macOS)
        return .macos
        #else
        return .ios
        #endif
    }

    #if os(macOS)
    /// Gets the hardware UUID on macOS
    private static var macHardwareUUID: String? {
        let platformExpertDevice = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        guard platformExpertDevice != 0 else { return nil }
        defer { IOObjectRelease(platformExpertDevice) }

        guard let uuidProperty = IORegistryEntryCreateCFProperty(
            platformExpertDevice,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else {
            return nil
        }

        return uuidProperty
    }
    #endif
}
