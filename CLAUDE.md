# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ReFocus is a cross-platform iOS/macOS productivity app that blocks distracting apps and websites during focus sessions. It uses:
- **Supabase** for real-time sync of timer state, websites, modes, schedules, settings, and stats
- **Screen Time API** (FamilyControls, ManagedSettings, DeviceActivity) for iOS enforcement
- **Network Extension** for macOS website blocking (requires Apple approval)
- **Safari Content Blocker** for synced website domain blocking
- **Gamification** with XP, streaks, achievements, and variable rewards

## Architecture

### Sync Strategy (Supabase Realtime)

| Data | Storage | Sync |
|------|---------|------|
| Timer state | Supabase | Real-time (one row per user) |
| Websites | Supabase + UserDefaults cache | Real-time |
| Focus modes | Supabase + UserDefaults cache | Real-time |
| Schedules | Supabase + UserDefaults cache | Real-time |
| User settings | Supabase | Real-time |
| User stats | Supabase (server-calculated) | Real-time |
| App selections (iOS) | UserDefaults only | Device-local (opaque tokens) |
| App selections (macOS) | UserDefaults only | Device-local (bundle IDs) |

### Key Managers (20 Total)

| Category | Managers |
|----------|----------|
| **Sync** | SupabaseManager, SyncCoordinator, TimerSyncManager, WebsiteSyncManager, FocusModeSyncManager, ScheduleSyncManager, UserSettingsSyncManager, UserStatsSyncManager, FocusSessionSyncManager |
| **Local State** | FocusModeManager, ScheduleManager, StatsManager, BlockEnforcementManager |
| **Feature** | FocusHeroManager, HardModeManager, RegretPreventionManager, DeepWorkCompanionManager, PremiumManager, RewardManager |
| **Platform** | iOSBlockEnforcer, NetworkExtensionManager, MacAppBlocker, SafariContentBlockerManager |

### Platform Enforcement

**iOS:**
- `iOSBlockEnforcer` uses multiple named `ManagedSettingsStore`s for context-specific blocking
- Named stores: `.timer`, `.schedule`, `.regretPrevention`, `.hardMode`
- Most restrictive setting wins when multiple stores have shields
- Safari Content Blocker handles synced website domain blocking

**macOS:**
- `MacAppBlocker` uses NSWorkspace observation to terminate blocked apps
- `NetworkExtensionManager` requires `com.apple.developer.networking.networkextension` entitlement

## Build Commands

```bash
# Build for iOS Simulator
xcodebuild -scheme ReFocus -destination 'platform=iOS Simulator,name=iPhone 17'

# Build for macOS
xcodebuild -scheme ReFocus -destination 'platform=macOS'
```

**Note:** Screen Time API blocking only works on physical devices, not simulators.

## Project Structure

```
ReFocus/
├── App/                    # App entry point, ContentView
├── Core/
│   ├── Models/             # Data models (FocusMode, FocusSchedule, etc.)
│   └── Managers/           # Sync managers, enforcement, rewards
├── Platform/
│   ├── iOS/                # Screen Time enforcement, Safari Content Blocker
│   └── macOS/              # Network Extension, NSWorkspace blocking
├── Features/
│   ├── Timer/              # Focus session UI
│   ├── Websites/           # Website management
│   ├── Apps/               # App selection
│   ├── FocusModes/         # Mode presets
│   ├── Settings/           # User preferences
│   ├── Stats/              # XP, streaks, achievements
│   ├── Hero/               # Companion system
│   ├── Premium/            # Premium features
│   ├── HardMode/           # Strict mode
│   └── RegretPrevention/   # Regret windows
├── DesignSystem/           # UI components, gradients
├── Database/               # Local SQL schema reference
└── Resources/              # Assets

Extensions:
├── ReFocusActivityReport/  # DeviceActivity reporting
├── ReFocusContentBlocker/  # Safari Content Blocker
└── ReFocusShield/          # Custom shield UI

Database:
└── supabase/
    ├── migrations/         # SQL migrations
    └── functions/          # Edge Functions (streak protection)
```

## Supabase Tables

| Table | Purpose |
|-------|---------|
| `timer_states` | Shared timer (one row per user) |
| `blocked_websites` | Synced website domains |
| `focus_sessions` | Session history |
| `focus_modes` | Focus mode presets |
| `focus_schedules` | Recurring schedules |
| `user_settings` | User preferences |
| `user_stats` | XP, level, streaks (server-calculated) |
| `achievements_earned` | Unlocked achievements |
| `bonus_rewards` | Variable reward history |
| `devices` | Device registration |

## Reward System

Based on gamification research (Duolingo: streaks +60% commitment, badges +30% completion):

- **XP Calculation**: 10 XP/minute base, multipliers for completion (1.5x), streaks (1.25-1.5x), hard mode (2x)
- **Streak Protection**: Users get 2 streak freezes per month
- **Variable Rewards**: 20% chance of bonus rewards per session
- **Achievement Types**: Session count, streak length, total time, special (early bird, night owl, etc.)

## Platform Constraints

### iOS Screen Time API Limitations
- Apps must be selected via `FamilyActivityPicker` (returns opaque tokens)
- Tokens are device-specific and cannot be synced
- Website domain strings from Supabase cannot be blocked via Screen Time
- Use Safari Content Blocker for synced website blocking

### macOS Network Extension
- Requires `com.apple.developer.networking.networkextension` entitlement
- Must apply for this entitlement from Apple
- App Group sharing required for extension communication

## Required Entitlements

### iOS
- `com.apple.developer.family-controls`
- `com.apple.security.application-groups`

### macOS
- `com.apple.security.app-sandbox`
- `com.apple.security.network.client`
- `com.apple.security.application-groups`
- `com.apple.developer.networking.networkextension` (requires Apple approval)

## Supabase Configuration

Update in `SupabaseManager.swift`:
```swift
private static let supabaseURL = "YOUR_SUPABASE_URL"
private static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
```

App Group: `group.com.refocus.shared`
