# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ReFocus is a minimal iOS/macOS productivity app that blocks apps and websites using Apple's Screen Time APIs. Built with SwiftUI, it follows an MVVM architecture with singleton managers for state coordination.

## Build Commands

```bash
# Build for iOS
xcodebuild -scheme ReFocus -destination 'platform=iOS Simulator,name=iPhone 17'

# Build for macOS
xcodebuild -scheme ReFocus -destination 'platform=macOS'
```

**Note:** Screen Time API blocking only works on physical devices, not simulators.

## Architecture

### Manager Pattern (Singletons)
- **FocusSessionManager.shared** - Session timing, countdown logic, history persistence
- **BlockManager.shared** - Screen Time API authorization, FamilyActivitySelection storage, ManagedSettingsStore enforcement
- **CloudKitSyncManager.shared** - iCloud sync for block list definitions

All managers are `@MainActor` ObservableObjects injected via `.environmentObject()`.

### Data Flow
```
ReFocusApp (initializes managers)
    ↓ @EnvironmentObject
ContentView (TabView navigation)
    ↓
FocusSessionView / BlockListsView / SettingsView
```

### Key Frameworks
- **FamilyControls** - Authorization via `AuthorizationCenter`, app selection via `FamilyActivityPicker`
- **ManagedSettings** - Block enforcement via `ManagedSettingsStore` with ApplicationTokens/WebDomainTokens
- **CloudKit** - Sync block list definitions (website domain strings) across devices

## Screen Time API Constraints

These are Apple-imposed limitations:

1. **Apps must be selected via FamilyActivityPicker** - Returns opaque `ApplicationToken`s, not bundle IDs
2. **Tokens are device-specific** - Cannot sync `ApplicationToken`/`WebDomainToken` between devices
3. **Blocks are device-local** - ManagedSettingsStore shields don't sync
4. **Website blocking is Safari-only** - Chrome/Firefox may not respect blocks

## Sync Strategy

- **Website domain strings** (e.g., "twitter.com") sync via CloudKit
- **App selections** (FamilyActivitySelection with tokens) are device-specific, stored locally
- When syncing from cloud, preserve local selectionData while updating website list

## Required Xcode Capabilities

- Family Controls (entitlement: `com.apple.developer.family-controls`)
- iCloud with CloudKit container: `iCloud.com.yourcompany.refocus`
- Info.plist key: `NSFamilyControlsUsageDescription`

## File Organization

| Path | Purpose |
|------|---------|
| `ReFocusApp.swift` | App entry point, environment setup |
| `ContentView.swift` | Root TabView (iOS) / NavigationSplitView (macOS) |
| `FocusSessionManager.swift` | Session state, timer, history (UserDefaults) |
| `BlockManager.swift` | Authorization, FamilyActivitySelection, blocking, CloudKit integration |
| `ModelsCloudKitSyncManager.swift` | CloudKit sync operations |
| `FocusSessionView.swift` | Timer UI, FamilyActivityPicker trigger |
| `BlockListsView.swift` | Block list CRUD, FamilyActivityPicker integration |
| `SettingsView.swift` | Authorization status, sync status |

## Data Models

### BlockList
```swift
struct BlockList: Identifiable, Codable {
    var id: UUID
    var name: String
    var websites: Set<String>     // Domain strings for sync
    var selectionData: Data?      // Encoded FamilyActivitySelection (device-specific)
    var appCount: Int             // For display
    var websiteTokenCount: Int    // For display
}
```

### FocusSession
```swift
struct FocusSession: Identifiable, Codable {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var plannedDuration: TimeInterval
    var actualDuration: TimeInterval?
    var blockListId: UUID?
    var blockListName: String?
}
```

## Data Persistence

- **UserDefaults:** `sessionHistory`, `blockLists` (JSON encoded)
- **CloudKit:** BlockList records (name, websites, lastModified), FocusSession records

## Platform Differences

- iOS/iPadOS: TabView navigation, full FamilyActivityPicker + ManagedSettingsStore support
- macOS: NavigationSplitView sidebar, Settings window; Screen Time API has limited support (consider Safari extension for website blocking)
