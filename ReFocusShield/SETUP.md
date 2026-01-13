# ReFocus Shield Configuration Setup

This extension customizes the Screen Time shield that appears when blocked apps are opened.

## Adding the Extension Target

1. Open ReFocus.xcodeproj in Xcode
2. File → New → Target
3. Search for "Shield Configuration" and select it
4. Name it "ReFocusShield"
5. Bundle Identifier: `Zero.Re-Focus.Shield`
6. Delete the auto-generated files and drag in the files from this folder:
   - `ShieldConfigurationExtension.swift`
   - `Info.plist`
   - `ReFocusShield.entitlements`

## Configuration

In the target settings:
- **Deployment Target**: iOS 17.0
- **Team**: Your development team
- **Signing**: Automatic with your team

## Entitlements

Ensure these entitlements are set:
- `com.apple.developer.family-controls`: YES
- `com.apple.security.application-groups`: `group.com.refocus.shared`

## What This Does

When a user opens a blocked app during a focus session, instead of the default
Screen Time shield, they'll see:

- Custom dark background matching ReFocus design
- App name with "is blocked" message
- Rotating motivational quotes about dreams and focus
- "Keep Focusing" button styled with ReFocus accent color

## Notes

- Shield configuration extensions run independently of the main app
- The extension reads from the shared App Group for any dynamic content
- Quotes are randomized each time the shield appears
