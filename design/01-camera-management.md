# Design: Camera Management

## Overview
Integrate AVFoundation to capture webcam feed, handle permissions, enumerate devices, and provide camera selection functionality.

## Goals
- Access and stream from macOS webcam
- Handle camera permissions gracefully
- Support multiple camera sources
- Provide camera device enumeration
- Efficient resource management (start/stop session)

## Architecture

### CameraManager Class

```swift
class CameraManager: NSObject {
    // MARK: - Properties
    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?

    var previewLayer: AVCaptureVideoPreviewLayer?
    var isSessionRunning: Bool { captureSession?.isRunning ?? false }

    // MARK: - Initialization
    func setup(with device: AVCaptureDevice?) async throws

    // MARK: - Session Control
    func startSession()
    func stopSession()

    // MARK: - Device Enumeration
    static func availableCameras() -> [AVCaptureDevice]

    // MARK: - Device Switching
    func switchToCamera(_ device: AVCaptureDevice) async throws
}
```

## Key Components

### 1. Permission Handling

**Info.plist Entry:**
```xml
<key>NSCameraUsageDescription</key>
<string>Iris needs camera access to display your webcam feed.</string>
```

**Permission Check:**
```swift
let status = AVCaptureDevice.authorizationStatus(for: .video)
switch status {
case .authorized:
    // Proceed with setup
case .notDetermined:
    // Request permission
    let granted = await AVCaptureDevice.requestAccess(for: .video)
case .denied, .restricted:
    // Show error dialog, can't proceed
}
```

### 2. Device Discovery

```swift
static func availableCameras() -> [AVCaptureDevice] {
    let discoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .externalUnknownCamera],
        mediaType: .video,
        position: .unspecified
    )
    return discoverySession.devices
}
```

**Device Types to Support:**
- `.builtInWideAngleCamera` - MacBook built-in camera
- `.externalUnknownCamera` - USB cameras, Continuity Camera

### 3. Capture Session Setup

```swift
func setup(with device: AVCaptureDevice?) async throws {
    // Create session
    let session = AVCaptureSession()
    session.beginConfiguration()

    // Use provided device or default
    let videoDevice = device ?? AVCaptureDevice.default(for: .video)
    guard let videoDevice = videoDevice else {
        throw CameraError.noDeviceAvailable
    }

    // Create input
    let input = try AVCaptureDeviceInput(device: videoDevice)
    guard session.canAddInput(input) else {
        throw CameraError.cannotAddInput
    }
    session.addInput(input)

    // Set session preset
    if session.canSetSessionPreset(.high) {
        session.sessionPreset = .high
    }

    session.commitConfiguration()

    // Create preview layer
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill

    // Store references
    self.captureSession = session
    self.videoDevice = videoDevice
    self.videoInput = input
    self.previewLayer = previewLayer
}
```

### 4. Session Lifecycle

```swift
func startSession() {
    guard let session = captureSession, !session.isRunning else { return }

    // Start on background thread
    DispatchQueue.global(qos: .userInitiated).async {
        session.startRunning()
    }
}

func stopSession() {
    guard let session = captureSession, session.isRunning else { return }

    // Stop on background thread
    DispatchQueue.global(qos: .userInitiated).async {
        session.stopRunning()
    }
}
```

### 5. Camera Switching

```swift
func switchToCamera(_ device: AVCaptureDevice) async throws {
    guard let session = captureSession else { return }

    let wasRunning = session.isRunning
    if wasRunning {
        stopSession()
    }

    session.beginConfiguration()

    // Remove old input
    if let oldInput = videoInput {
        session.removeInput(oldInput)
    }

    // Add new input
    let newInput = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(newInput) else {
        session.commitConfiguration()
        throw CameraError.cannotAddInput
    }
    session.addInput(newInput)

    session.commitConfiguration()

    // Update references
    self.videoDevice = device
    self.videoInput = newInput

    if wasRunning {
        startSession()
    }
}
```

## Error Handling

### Custom Error Types
```swift
enum CameraError: Error, LocalizedError {
    case noDeviceAvailable
    case permissionDenied
    case cannotAddInput
    case sessionConfigurationFailed

    var errorDescription: String? {
        switch self {
        case .noDeviceAvailable:
            return "No camera device found"
        case .permissionDenied:
            return "Camera access denied. Enable in System Settings."
        case .cannotAddInput:
            return "Cannot configure camera"
        case .sessionConfigurationFailed:
            return "Failed to configure camera session"
        }
    }
}
```

### User-Facing Error Messages
- **No Camera**: "No camera detected. Please connect a camera."
- **Permission Denied**: "Iris needs camera access. Enable it in System Settings > Privacy & Security > Camera."
- **Camera In Use**: "Camera is in use by another app."

## Integration with Window

The `CircularWindow` (design/02) will:
1. Get `previewLayer` from `CameraManager`
2. Add layer to window's content view
3. Apply circular mask on top of preview layer

```swift
// In CircularWindow
if let previewLayer = cameraManager.previewLayer {
    previewLayer.frame = contentView.bounds
    contentView.layer?.addSublayer(previewLayer)
}
```

## Resource Management

### When to Start/Stop Session

**Start:**
- When window becomes visible
- On app launch if window is set to show

**Stop:**
- When window is hidden
- On app quit
- When switching cameras (temporarily)

**Why:** Camera uses significant resources (CPU, memory, battery). Stop when not needed.

### Memory Considerations
- Stop session when window hidden to save resources
- Clean up properly in deinit
- Remove observers

## Testing Scenarios

### Permission States
- [ ] First launch (not determined) - shows permission dialog
- [ ] Permission granted - camera works
- [ ] Permission denied - shows error message with guidance
- [ ] Permission revoked while running - handles gracefully

### Device Scenarios
- [ ] MacBook built-in camera
- [ ] External USB camera
- [ ] Multiple cameras connected
- [ ] No camera connected
- [ ] Camera disconnected while running
- [ ] Camera connected while running

### Performance
- [ ] Camera starts within 1 second
- [ ] Smooth video (no stuttering)
- [ ] CPU usage reasonable (< 20% on modern Mac)
- [ ] No memory leaks after repeated start/stop

## Implementation Checklist

When implementing:
- [ ] Create CameraManager class
- [ ] Add camera usage description to Info.plist
- [ ] Implement permission checking and requesting
- [ ] Implement device enumeration
- [ ] Implement session setup
- [ ] Implement start/stop session
- [ ] Implement camera switching
- [ ] Add proper error handling
- [ ] Test with no camera
- [ ] Test with denied permissions
- [ ] Test with multiple cameras
- [ ] Verify resource cleanup

## Common Pitfalls

### 1. UI Thread Blocking
❌ **Don't:**
```swift
session.startRunning()  // Blocks main thread
```

✅ **Do:**
```swift
DispatchQueue.global(qos: .userInitiated).async {
    session.startRunning()
}
```

### 2. Session Configuration
❌ **Don't:** Modify session while running
✅ **Do:** Call `beginConfiguration()` and `commitConfiguration()`

### 3. Resource Cleanup
❌ **Don't:** Leave session running when hidden
✅ **Do:** Stop session when window hidden

### 4. Permission Timing
❌ **Don't:** Assume permission is granted
✅ **Do:** Check permission before every session setup

## Dependencies
- AVFoundation framework
- Runs on background thread for session operations
- Provides preview layer to CircularWindow

## Next Steps
After camera management is working:
- Create CircularWindow (design/02) that uses the preview layer
- Add camera selection menu to MenuBarController (design/03)
