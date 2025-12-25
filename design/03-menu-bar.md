# Design: Menu Bar Controller

## Overview
Create a menu bar (status bar) controller that provides the primary interface for controlling the Iris app: toggle window visibility, select camera source, and quit the app.

## Goals
- Menu bar icon in the system status bar (top right)
- Click icon to toggle window show/hide
- Menu with camera selection and preferences
- Quit option
- Support for light/dark mode

## Architecture

### MenuBarController Class

```swift
class MenuBarController: NSObject {
    // MARK: - Properties
    private var statusItem: NSStatusItem?
    private var circularWindow: CircularWindow?
    private var cameraManager: CameraManager

    // MARK: - Initialization
    init(window: CircularWindow, cameraManager: CameraManager)

    // MARK: - Setup
    func setupMenuBar()
    func createMenu() -> NSMenu

    // MARK: - Actions
    @objc func toggleWindow()
    @objc func selectCamera(_ sender: NSMenuItem)
    @objc func quit()
}
```

## Key Components

### 1. Status Item Creation

```swift
func setupMenuBar() {
    // Create status item with variable length
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    guard let statusItem = statusItem else { return }
    guard let button = statusItem.button else { return }

    // Set icon (template image for dark/light mode)
    if let image = NSImage(named: "MenuBarIcon") {
        image.isTemplate = true  // Automatic dark/light mode
        button.image = image
    } else {
        // Fallback text if no icon
        button.title = "👁"  // Eye emoji as fallback
    }

    // Set tooltip
    button.toolTip = "Iris - Click to toggle window"

    // Set action - click to toggle
    button.action = #selector(toggleWindow)
    button.target = self

    // Right-click or option-click for menu
    statusItem.menu = createMenu()
}
```

### 2. Menu Structure

```
┌─────────────────────────┐
│ Hide Window       ⌘H     │  (or "Show Window" when hidden)
├─────────────────────────┤
│ Camera                 ▸│
│   ├ ✓ FaceTime HD       │
│   ├   USB Camera        │
│   └   iPhone Camera     │
├─────────────────────────┤
│ Launch at Login         │  (checkbox)
├─────────────────────────┤
│ Quit Iris         ⌘Q    │
└─────────────────────────┘
```

### 3. Creating the Menu

```swift
func createMenu() -> NSMenu {
    let menu = NSMenu()

    // Toggle window item
    let toggleItem = NSMenuItem(
        title: circularWindow?.isVisible == true ? "Hide Window" : "Show Window",
        action: #selector(toggleWindow),
        keyEquivalent: "h"
    )
    toggleItem.target = self
    menu.addItem(toggleItem)

    menu.addItem(NSMenuItem.separator())

    // Camera selection submenu
    let cameraMenuItem = NSMenuItem(title: "Camera", action: nil, keyEquivalent: "")
    let cameraSubmenu = createCameraSubmenu()
    cameraMenuItem.submenu = cameraSubmenu
    menu.addItem(cameraMenuItem)

    menu.addItem(NSMenuItem.separator())

    // Launch at login
    let launchItem = NSMenuItem(
        title: "Launch at Login",
        action: #selector(toggleLaunchAtLogin),
        keyEquivalent: ""
    )
    launchItem.target = self
    launchItem.state = isLaunchAtLoginEnabled() ? .on : .off
    menu.addItem(launchItem)

    menu.addItem(NSMenuItem.separator())

    // Quit
    let quitItem = NSMenuItem(
        title: "Quit Iris",
        action: #selector(quit),
        keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    return menu
}
```

### 4. Camera Selection Submenu

```swift
func createCameraSubmenu() -> NSMenu {
    let menu = NSMenu()

    let cameras = CameraManager.availableCameras()

    if cameras.isEmpty {
        let noCamera = NSMenuItem(title: "No Camera Available", action: nil, keyEquivalent: "")
        noCamera.isEnabled = false
        menu.addItem(noCamera)
        return menu
    }

    let currentDevice = cameraManager.currentDevice

    for camera in cameras {
        let item = NSMenuItem(
            title: camera.localizedName,
            action: #selector(selectCamera(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = camera  // Store device reference

        // Checkmark for current camera
        if camera.uniqueID == currentDevice?.uniqueID {
            item.state = .on
        }

        menu.addItem(item)
    }

    return menu
}
```

### 5. Toggle Window Action

```swift
@objc func toggleWindow() {
    guard let window = circularWindow else { return }

    if window.isVisible {
        window.hide()
    } else {
        window.show()
    }

    // Update menu item title
    if let statusItem = statusItem {
        statusItem.menu = createMenu()  // Refresh menu
    }
}
```

### 6. Camera Selection Action

```swift
@objc func selectCamera(_ sender: NSMenuItem) {
    guard let device = sender.representedObject as? AVCaptureDevice else { return }

    Task {
        do {
            try await cameraManager.switchToCamera(device)

            // Update menu checkmarks
            DispatchQueue.main.async {
                self.statusItem?.menu = self.createMenu()
            }
        } catch {
            // Show error alert
            showError("Failed to switch camera: \(error.localizedDescription)")
        }
    }
}
```

### 7. Quit Action

```swift
@objc func quit() {
    // Clean up camera resources
    cameraManager.stopSession()

    // Quit app
    NSApplication.shared.terminate(nil)
}
```

## Click Behavior

### Primary Click (Left-Click)
- **Action:** Toggle window show/hide
- **No menu shown**
- Fast and convenient

### Secondary Interaction (Right-Click or Hold)
- **Action:** Show full menu
- **Access:** Camera selection, preferences, quit
- Alternative: Hold Option key while clicking

**Implementation:**
```swift
// In setupMenuBar()
button.sendAction(on: [.leftMouseUp, .rightMouseUp])

// Custom handling in button subclass or tracking area
if event.type == .rightMouseDown {
    statusItem.menu?.popUp(...)
} else {
    toggleWindow()
}
```

**Alternative simpler approach:** Always show menu, but add "Show/Hide Window" as first item.

## Menu Bar Icon

### Icon Design
- **Size:** 16x16 points @1x, 32x32 @2x, 48x48 @3x
- **Style:** Simple, monochrome (single color)
- **Format:** PDF or PNG with @2x, @3x variants
- **Name:** MenuBarIcon.pdf (in Assets.xcassets)

### Icon Suggestions
- Eye icon (👁)
- Circle icon (○)
- Camera icon (📷)
- Custom designed icon

### Template Image
```swift
image.isTemplate = true
```
- **True:** Icon adapts to menu bar appearance (black in light mode, white in dark mode)
- **False:** Icon uses original colors

**Use template = true** for proper dark/light mode support.

## Dynamic Menu Updates

### When to Refresh Menu
- After camera device changes (plugged/unplugged)
- After window show/hide
- After launch at login toggle
- On camera switch success/failure

### Menu Refresh
```swift
// Simple approach: recreate menu
statusItem?.menu = createMenu()

// Advanced: Update specific items (more efficient)
if let toggleItem = menu.item(at: 0) {
    toggleItem.title = window.isVisible ? "Hide Window" : "Show Window"
}
```

## Notifications

### Respond to External Events

```swift
// Camera device changes
NotificationCenter.default.addObserver(
    self,
    selector: #selector(devicesDidChange),
    name: .AVCaptureDeviceWasConnected,
    object: nil
)

NotificationCenter.default.addObserver(
    self,
    selector: #selector(devicesDidChange),
    name: .AVCaptureDeviceWasDisconnected,
    object: nil
)

@objc func devicesDidChange() {
    // Refresh camera submenu
    statusItem?.menu = createMenu()
}
```

## Error Handling

### Camera Switch Failure
```swift
func showError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Camera Error"
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}
```

### No Cameras Available
- Show "No Camera Available" in submenu
- Disable camera menu items
- Show alert if user tries to show window with no camera

## Testing Checklist

### Visual
- [ ] Icon appears in menu bar (top right)
- [ ] Icon adapts to dark/light mode
- [ ] Menu appears when clicking icon (or right-clicking)
- [ ] Menu items are readable
- [ ] Checkmark shows on current camera

### Behavior
- [ ] Click icon toggles window show/hide
- [ ] "Show/Hide Window" text updates correctly
- [ ] Selecting camera switches successfully
- [ ] Current camera has checkmark
- [ ] Multiple cameras appear in list
- [ ] "No Camera Available" shows when no cameras
- [ ] Quit button exits app cleanly

### Dynamic Updates
- [ ] Menu updates when camera plugged/unplugged
- [ ] Menu updates after window toggle
- [ ] Checkmark updates after camera switch

### Keyboard Shortcuts
- [ ] ⌘H hides/shows window
- [ ] ⌘Q quits app

## Implementation Checklist

- [ ] Create MenuBarController class
- [ ] Create status item with NSStatusBar
- [ ] Add menu bar icon asset (template image)
- [ ] Implement click action to toggle window
- [ ] Create menu structure
- [ ] Implement camera submenu with device list
- [ ] Add checkmark for current camera
- [ ] Implement camera selection action
- [ ] Implement quit action
- [ ] Add device change notifications
- [ ] Test with multiple cameras
- [ ] Test with no camera
- [ ] Verify icon in light and dark mode

## Common Pitfalls

### 1. Menu Doesn't Appear
**Cause:** No menu assigned, or wrong click type
**Solution:** Set `statusItem.menu = createMenu()`

### 2. Icon Wrong Color
**Cause:** `isTemplate = false`
**Solution:** Set `image.isTemplate = true`

### 3. Camera Checkmark Wrong
**Cause:** Not comparing device IDs correctly
**Solution:** Use `device.uniqueID` for comparison

### 4. Menu Doesn't Update
**Cause:** Menu not refreshed after state change
**Solution:** Recreate menu: `statusItem.menu = createMenu()`

### 5. Toggle Action Doesn't Work
**Cause:** Button action not set, or wrong target
**Solution:** Set `button.action` and `button.target`

### 6. Keyboard Shortcuts Conflict
**Cause:** System shortcuts take precedence
**Solution:** Use standard shortcuts (⌘H, ⌘Q)

## Launch at Login

See design/05-preferences.md for implementation details.

Preview:
```swift
func toggleLaunchAtLogin() {
    if isLaunchAtLoginEnabled() {
        disableLaunchAtLogin()
    } else {
        enableLaunchAtLogin()
    }
    // Refresh menu to update checkbox
    statusItem?.menu = createMenu()
}
```

## Dependencies
- CircularWindow (to show/hide)
- CameraManager (to switch cameras, enumerate devices)
- AppKit (NSStatusBar, NSMenu)

## Next Steps
After menu bar works:
- Add resize interaction (design/04)
- Add preferences persistence (design/05)
- Wire up launch at login (design/05)
