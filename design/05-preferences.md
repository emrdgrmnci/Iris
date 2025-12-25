# Design: Preferences & Persistence

## Overview
Persist user preferences across app launches including window size, position, selected camera, and launch at login setting.

## Goals
- Remember window size and position
- Remember selected camera device
- Remember whether window was visible on quit
- Launch at login functionality
- Survive app restarts, system reboots, and screen changes

## What to Persist

### Window State
- **Size:** Diameter of circular window (100-600 points)
- **Position:** X, Y coordinates on screen
- **Visibility:** Whether window was shown or hidden on quit
- **Screen:** Which screen the window was on (if multi-monitor)

### Camera Settings
- **Device ID:** Unique identifier of selected camera
- **Fallback:** If saved camera unavailable, use default

### App Settings
- **Launch at Login:** Boolean preference
- **First Launch:** Track if this is first time running (show welcome/tutorial)

## Storage Mechanism

### UserDefaults
Use macOS UserDefaults for all preferences:
- Built-in macOS persistence system
- Automatic synchronization
- Simple key-value storage
- Survives app updates and reboots

### Preference Keys
```
com.iris.app.windowSize         -> CGFloat
com.iris.app.windowX            -> CGFloat
com.iris.app.windowY            -> CGFloat
com.iris.app.windowVisible      -> Bool
com.iris.app.selectedCameraID   -> String
com.iris.app.launchAtLogin      -> Bool
com.iris.app.firstLaunch        -> Bool
```

## PreferencesManager

### Responsibilities
- Centralized access to all preferences
- Save preferences when changes occur
- Load preferences on app launch
- Provide sensible defaults

### When to Save
- **Window size:** After resize gesture completes
- **Window position:** After window dragged to new location
- **Window visibility:** On app quit
- **Camera selection:** When user selects different camera
- **Launch at login:** When user toggles setting

### When to Load
- **App launch:** Read all preferences
- **Apply to window:** Restore size, position, visibility
- **Apply to camera:** Select previously used camera (if available)

## Launch at Login

### macOS Integration
Use ServiceManagement framework (modern approach) or Login Items:
- Add app to user's login items
- Runs automatically when user logs in
- Can be toggled on/off by user

### Implementation Approach
**Modern (macOS 13+):** SMAppService
- Recommended for new apps
- More reliable
- Less user friction

**Legacy (macOS 12 and earlier):** LSSharedFileList
- Backwards compatible
- More complex API

**Decision:** Target macOS 13+ for simplicity, use SMAppService.

### User Control
- Toggle via menu bar menu
- Checkbox shows current state
- Changes take effect immediately

## Window Position Restoration

### Single Monitor
Straightforward - restore to saved X, Y coordinates.

### Multi-Monitor
Challenges:
- **Screen disconnected:** Window may be on non-existent screen
- **Resolution changed:** Saved position may be off-screen
- **Different arrangement:** Screens rearranged

### Smart Restoration Strategy
1. Try to restore to saved screen (by screen ID)
2. If screen not available, use main screen
3. Verify window is fully visible (not off-screen)
4. If off-screen, move to center of main screen

### Screen Coordinate Space
macOS uses global coordinate space across all screens:
- Origin (0, 0) at bottom-left of primary display
- Y-axis increases upward
- Account for menu bar height

## Default Values

### First Launch
When app runs for first time:
- **Window size:** 200x200 (comfortable default)
- **Window position:** Center of main screen
- **Window visibility:** Show (so user sees something)
- **Camera:** Default system camera
- **Launch at login:** Off (don't be intrusive)

### Reasonable Defaults
If saved values are corrupted or invalid:
- Fall back to defaults above
- Log warning for debugging
- Don't crash

## Camera Device Persistence

### Challenge
Camera devices don't have stable IDs across reboots in some cases.

### Best Effort Approach
- Save camera `uniqueID` string
- On launch, try to find camera with matching ID
- If not found, fall back to default camera
- If multiple cameras match (rare), use first match

### User Experience
If saved camera not available:
- Use default camera silently
- User can manually select correct camera
- New selection is saved

## Preference Migration

### Future-Proofing
When adding new preferences:
- Provide default values
- Don't break existing installations
- Handle missing keys gracefully

### Version Tracking
Optional: Track preference schema version for major changes.

## Testing Checklist

### Persistence
- [ ] Window size persists across app restarts
- [ ] Window position persists across app restarts
- [ ] Window visibility persists (show/hide state)
- [ ] Selected camera persists
- [ ] Launch at login setting persists

### Multi-Monitor
- [ ] Window restores to correct screen
- [ ] Window appears on main screen if saved screen disconnected
- [ ] Window doesn't appear off-screen
- [ ] Works when switching from laptop to external monitor
- [ ] Works when changing screen arrangement

### Edge Cases
- [ ] First launch shows default values
- [ ] Corrupted preferences fall back to defaults
- [ ] Saved camera unavailable - uses default
- [ ] Window saved off-screen - moves to visible area
- [ ] Handles very old or future preference versions

### Launch at Login
- [ ] Enable launch at login - app launches on login
- [ ] Disable launch at login - app doesn't launch
- [ ] Toggle works immediately
- [ ] Persists across reboots

## Implementation Checklist

- [ ] Create PreferencesManager class/struct
- [ ] Define all preference keys
- [ ] Implement save methods for each preference
- [ ] Implement load methods with defaults
- [ ] Add window position/size saving on change
- [ ] Add window position/size restoration on launch
- [ ] Add camera selection saving/restoration
- [ ] Add window visibility state saving/restoration
- [ ] Implement launch at login (SMAppService)
- [ ] Add launch at login toggle to menu
- [ ] Test multi-monitor scenarios
- [ ] Test first launch experience
- [ ] Verify all preferences persist correctly

## Common Pitfalls

### 1. Saving Too Frequently
Don't save on every mouse move during window drag - save when drag ends.

### 2. Off-Screen Windows
Always verify window frame is within visible screen bounds before restoring.

### 3. Camera ID Not Found
Gracefully fall back to default camera if saved ID doesn't exist.

### 4. Coordinate System Confusion
Remember macOS uses bottom-left origin, Y increases upward.

### 5. Launch at Login Permission
Modern macOS requires user approval for launch at login in some cases.

## Privacy & Security

### No Sensitive Data
All preferences are non-sensitive:
- Window geometry (not private)
- Camera device ID (hardware identifier, not content)
- UI state (not personal)

### UserDefaults Location
Stored in: `~/Library/Preferences/com.iris.app.plist`
- User-accessible
- Not synced via iCloud (unless explicitly enabled)
- Survives app deletion (until manually cleared)

## Dependencies
- UserDefaults (Foundation)
- SMAppService (ServiceManagement) - for launch at login
- NSScreen (AppKit) - for screen bounds checking

## Next Steps
After preferences work:
- App is feature-complete
- Focus on polish and bug fixes
- Prepare for distribution (build scripts, DMG, etc.)
