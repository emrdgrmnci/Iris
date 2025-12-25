# Design: Project Setup

## Overview
Set up the Iris macOS application project structure with command-line build capability, no Xcode IDE required.

## Goals
- Create a minimal macOS application project
- Enable command-line building via `xcodebuild`
- Provide simple build/run/clean scripts
- Configure app to run as menu bar only (no Dock icon)

## Project Structure

```
iris/
├── Iris/
│   ├── Iris.xcodeproj/
│   │   └── project.pbxproj          # Xcode project file
│   ├── Iris/
│   │   ├── AppDelegate.swift        # App entry point
│   │   ├── Info.plist              # App configuration
│   │   └── Assets.xcassets/        # Images, icons
│   └── Iris.entitlements           # App permissions
├── build.sh                        # Build script
├── run.sh                          # Run script
└── clean.sh                        # Clean script
```

## Key Configuration

### Info.plist Settings
```xml
<key>LSUIElement</key>
<true/>
```
- `LSUIElement = true` makes the app menu bar only (no Dock icon)

### Entitlements
```xml
<key>com.apple.security.device.camera</key>
<true/>
```
- Camera access permission

### Bundle Identifier
- Use: `com.iris.app` or similar
- Needed for preferences and permissions

## Build Scripts

### build.sh
```bash
#!/bin/bash
cd Iris
xcodebuild -project Iris.xcodeproj \
           -scheme Iris \
           -configuration Release \
           build
```

### run.sh
```bash
#!/bin/bash
# Build first
./build.sh

# Run the built app
open Iris/build/Release/Iris.app
```

### clean.sh
```bash
#!/bin/bash
cd Iris
xcodebuild -project Iris.xcodeproj \
           -scheme Iris \
           clean
rm -rf build/
```

## AppDelegate.swift Structure

```swift
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize menu bar controller
        // Initialize camera manager
        // Show initial window
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Cleanup camera resources
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Return false - app lives in menu bar even when window closed
        return false
    }
}
```

## Prerequisites

### Required Tools
- macOS 11.0 or later (target)
- Xcode Command Line Tools: `xcode-select --install`
- Swift 5.5 or later

### Checking Installation
```bash
# Check if command line tools installed
xcode-select -p

# Check Swift version
swift --version
```

## Implementation Steps

1. **Create Xcode Project**
   - Use `xcodebuild` or manually create project structure
   - Set up basic macOS app template
   - Configure target for macOS 11.0+

2. **Configure Info.plist**
   - Add `LSUIElement = true`
   - Add camera usage description
   - Set bundle identifier

3. **Create Entitlements File**
   - Add camera permission
   - Add hardened runtime if needed

4. **Write AppDelegate**
   - Basic app lifecycle
   - No main window initially (menu bar only)

5. **Create Build Scripts**
   - Ensure scripts are executable: `chmod +x *.sh`
   - Test build from command line

6. **Verify**
   - Run `./build.sh` - should compile without errors
   - Run `./run.sh` - should launch (app won't do much yet)
   - App should NOT appear in Dock
   - App should appear in menu bar (top right)

## Testing Checklist

- [ ] Project builds from command line
- [ ] No Xcode IDE needed
- [ ] App launches via `./run.sh`
- [ ] App appears in menu bar only (not Dock)
- [ ] App doesn't crash on launch
- [ ] Can quit app from menu bar icon

## Common Issues

### Issue: "xcodebuild: command not found"
**Solution**: Install Command Line Tools
```bash
xcode-select --install
```

### Issue: App crashes on launch
**Solution**: Check Console.app for crash logs, verify Info.plist is valid XML

### Issue: App appears in Dock
**Solution**: Verify `LSUIElement = true` in Info.plist

### Issue: Build fails with signing errors
**Solution**: For development, use automatic signing or sign with ad-hoc certificate

## Agent Checklist

When implementing this:
- [ ] Create proper Xcode project structure
- [ ] Set `LSUIElement = true` in Info.plist
- [ ] Add camera entitlement
- [ ] Create all three build scripts
- [ ] Make scripts executable
- [ ] Add basic AppDelegate with menu bar presence
- [ ] Test that app builds and runs from command line
- [ ] Verify app is menu-bar-only (no Dock icon)

## Notes

- Keep the initial setup minimal - just enough to launch
- Don't implement camera or window yet - those come in later design docs
- Focus on command-line buildability
- The app should launch and show a menu bar icon (can be default for now)
