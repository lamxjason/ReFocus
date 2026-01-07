# ReFocus Product Principles

> **North Star:** Restore human attention, reduce compulsive app and website usage, and help people focus on meaningful work, relationships, and purpose.

## Core Philosophy

ReFocus exists to give people their time back. It should feel like a **tool**, not another app competing for attention. Every feature must pass this test:

> "Does this help users focus more, or does this make them spend more time in our app?"

If the answer is the latter, it doesn't belong in ReFocus.

---

## Non-Negotiable Principles

### 1. Science-Backed, Not Engagement-Optimized

- All behavior design must align with cognitive psychology research
- **Streaks are acceptable** - research shows they increase commitment by ~60% (Duolingo studies)
- **Variable ratio rewards are NOT acceptable** - they exploit the same psychology as slot machines
- We measure success by **time NOT spent in distracting apps**, not time spent in ReFocus

### 2. Zero Dark Patterns

The following are explicitly forbidden:

- [ ] Slot machine mechanics (random rewards with varying rarity)
- [ ] Artificial scarcity ("Only 2 streak freezes left!")
- [ ] FOMO-inducing notifications
- [ ] Gamification that creates anxiety (fear of losing streaks)
- [ ] Vanity metrics (levels, XP that don't serve user goals)
- [ ] Celebrations that require dismissal before continuing

**Allowed:**
- Simple progress tracking (hours focused, sessions completed)
- Streaks (with graceful handling of missed days)
- Clear, factual notifications about schedule start/end

### 3. Intentional Friction (Only Where It Helps)

Add friction to:
- Ending a focus session early (confirmation delay)
- Disabling blocking during active session (strict mode)

Remove friction from:
- Starting a focus session (one-tap activation)
- Setting up blocking (smart defaults)
- Cross-device sync (automatic, invisible)

### 4. Calm by Default

The app should feel:
- **Invisible when working** - no popups, badges, or celebrations during focus
- **Powerful when needed** - blocking should be rock-solid
- **Effortless to use** - minimal decisions required
- **Emotionally grounding** - no anxiety, urgency, or competition

### 5. Apple-Level Polish

- UI must feel premium, minimal, and timeless
- No visual clutter or busy interfaces
- Animations should be subtle and purposeful
- Dark mode as the primary (and possibly only) appearance

### 6. Trust Over Growth

We optimize for:
- User trust and long-term well-being
- Actual focus time achieved (not app engagement)
- Word-of-mouth from satisfied users

We do NOT optimize for:
- Daily active users
- Session length in our app
- Notification engagement rates

---

## Feature Evaluation Framework

Before adding any feature, answer these questions:

1. **Does this help users focus?** If no, don't build it.
2. **Does this create anxiety or urgency?** If yes, redesign or cut it.
3. **Does this require user attention during focus?** If yes, cut it.
4. **Could this become addictive?** If yes, cut it.
5. **Does this add complexity to the core experience?** If yes, find a simpler alternative.

---

## What ReFocus IS

- A tool that blocks distracting apps and websites
- A timer that syncs across your devices
- A scheduler for automated focus periods
- A simple record of your focus sessions

## What ReFocus IS NOT

- A game with levels, XP, and achievements to chase
- A social network with leaderboards and challenges
- An AI companion that talks to you
- A productivity system that tells you how to work

---

## Current Technical Debt (To Address)

### Critical: Remove Variable Rewards System ✅ DISABLED

**Status:** Disabled for new users (minimal mode default). Code remains but is not executed.

The `RewardManager` implements literal gambling mechanics:
- 20% base chance of reward, scaling up to 40% with streaks
- Rarity tiers: Common (60%), Uncommon (25%), Rare (12%), Legendary (3%)
- Random rolls with weighted probabilities
- "Variable rewards to maintain anticipation" (per docstring)

**Current Mitigation:**
- `checkForReward()` only called when `shouldShowRewardPopups` is true (not in minimal mode)
- `consumeDoubleXP()` explicitly skipped in minimal mode
- New users never see or experience this system

**Future Action:**
- Remove `RewardManager.swift` entirely
- Remove `RewardPopupView.swift`
- Clean up related UI code

**Alternative approach (already implemented):**
- Simple, predictable progress tracking (focus time, sessions completed)
- Streaks (research-backed, graceful handling)
- No random rewards, no gambling mechanics

### High: Simplify Gamification
Current XP/Level system creates engagement loops. Consider:
- Remove levels entirely, OR
- Make levels purely informational (no celebrations, no multipliers)
- Remove achievement popups (show in a quiet "History" section instead)

### High: Remove FocusHero System
The FocusHero system is a full RPG-style character system with hero classes, equipment slots (weapon, armor, accessory, aura), evolution tiers, and character customization.

**Analysis:** This system fundamentally contradicts our North Star:
- It's gamification for engagement, not focus
- Equipment unlocks create anticipation loops
- Evolution celebrations are dopamine triggers
- Character customization adds cognitive overhead
- It doesn't help users focus at all

**Recommendation:** Deprecate and remove entirely. In the interim:
- Disable hero sync when minimal mode is enabled (default)
- Do not expose Hero UI to new users
- Consider removing in a future version

### Medium: Reduce Code Complexity
- FocusSessionView is 2500+ lines - split into smaller components
- 20+ managers creates cognitive overhead - consolidate where possible

### Low: UI Simplification
- Timer vs Schedule toggle adds decision fatigue
- Circular schedule clock overlay is visually complex
- Consider unified interface that handles both use cases

---

## Success Metrics (What We Measure)

### Primary
- Hours of focus time achieved by users
- Percentage of focus sessions completed (not abandoned)
- Cross-device sync reliability

### Secondary
- User retention at 30/90/365 days (indicates genuine value)
- Word-of-mouth referrals
- App Store ratings and reviews

### What We Don't Track
- Daily active users (vanity metric)
- Session count in our app
- Notification tap rates
- Achievement unlock rates

---

## Subscription Philosophy

Users pay for:
- Cross-device sync (genuine technical value)
- Advanced scheduling features
- Strict mode (commitment device)

Users do NOT pay for:
- Removing artificial limits
- Unlocking "premium" game content
- Access to their own data

The subscription should feel like paying for a tool, not unlocking a game.

---

## Future Improvements (UX Polish)

### One-Tap Activation
Currently, `selectedDuration` resets to 25 minutes on each app launch. For true one-tap activation:
- Persist last selected duration in UserDefaults
- Persist last selected focus mode
- One tap = start with user's preferred settings

### UI Simplification
- Consider removing Timer vs Schedule toggle (unified experience)
- Evaluate circular schedule clock complexity
- Explore "quick start" presets for frequent durations

### Code Cleanup
- Remove deprecated code (RewardManager, FocusHero) once stable
- Split FocusSessionView into smaller components (~2500 lines currently)
- Fix unused variable warnings in LevelUpCelebrationView

---

## Implementation Status (as of 2026-01-08)

### Completed
- [x] Minimal Mode implemented and set as DEFAULT for new users
- [x] All gamification DISABLED in minimal mode:
  - Reward popups
  - Reward calculation (gambling mechanics)
  - Double XP bonuses
  - XP/Level display in Stats
  - Achievement section in Stats
  - Level up celebrations
  - Achievement popups
  - Streak warning banners
  - FocusHero system sync
- [x] PRODUCT_PRINCIPLES.md comprehensive documentation
- [x] iOS and macOS builds verified

### New User Experience
New users now get a **calm, tool-like focus app** with:
- Clean timer interface
- No gamification (no XP, levels, achievements)
- No popups after sessions
- Simple stats: focus time, sessions, streaks
- No dark patterns or engagement loops

### For Users Who Want Gamification
Users can disable Minimal Mode in Settings to restore:
- XP/Level tracking
- Achievement celebrations
- Reward popups (variable rewards)
- FocusHero progression

---

*Last updated: 2026-01-08*
*This document guides all product decisions. When in doubt, refer here.*
