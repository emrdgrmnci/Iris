# Design: Circular Window

## Overview
Create a custom NSWindow that displays the camera feed in a circular shape, remains always-on-top, and has a transparent background.

## Goals
- Circular window shape (no rectangular frame)
- Always-on-top behavior
- Transparent background outside the circle
- Display camera preview layer inside
- Support window dragging
- Clean visual appearance

## Architecture

### CircularWindow Class

```swift
class CircularWindow: NSWindow {
    // MARK: - Properties
    private let circularView: CircularContentView
    private var cameraManager: CameraManager

    // MARK: - Initialization
    init(cameraManager: CameraManager, size: CGFloat = 200)

    // MARK: - Window Configuration
    func configureWindow()
    func setupVideoPreview()

    // MARK: - Visibility
    func show()
    func hide()
}
```

### CircularContentView Class

```swift
class CircularContentView: NSView {
    // MARK: - Properties
    private var maskLayer: CAShapeLayer?

    // MARK: - Drawing
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer()

    // MARK: - Layout
    override func layout()
    func updateMask()
}
```

## Key Components

### 1. Window Configuration

```swift
init(cameraManager: CameraManager, size: CGFloat = 200) {
    self.cameraManager = cameraManager

    // Calculate initial position (center of screen)
    let screenRect = NSScreen.main?.visibleFrame ?? .zero
    let origin = CGPoint(
        x: screenRect.midX - size/2,
        y: screenRect.midY - size/2
    )
    let rect = CGRect(origin: origin, size: CGSize(width: size, height: size))

    // Create content view
    self.circularView = CircularContentView(frame: NSRect(origin: .zero, size: rect.size))

    // Initialize window
    super.init(
        contentRect: rect,
        styleMask: [.borderless, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )

    configureWindow()
    setupVideoPreview()
}

func configureWindow() {
    // Make window always on top
    self.level = .floating

    // Transparent background
    self.isOpaque = false
    self.backgroundColor = .clear

    // No shadow initially (circular shadow added via content view)
    self.hasShadow = true

    // Allow dragging by clicking anywhere in window
    self.isMovableByWindowBackground = true

    // Set content view
    self.contentView = circularView
}
```

### 2. Window Levels

```swift
// Window levels (lower to higher)
.normal          // Regular app windows
.floating        // Always on top (use this)
.statusBar       // Menu bar items
.screenSaver     // Screen saver
```

**Use `.floating`** - stays above normal windows but below menu bar.

### 3. Circular Masking

```swift
class CircularContentView: NSView {

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        guard let layer = self.layer else { return }

        // Background color (visible inside circle)
        layer.backgroundColor = NSColor.black.cgColor

        // Update mask
        updateMask()
    }

    override func layout() {
        super.layout()
        updateMask()
    }

    func updateMask() {
        // Create circular mask
        let diameter = min(bounds.width, bounds.height)
        let rect = CGRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )

        let maskLayer = CAShapeLayer()
        maskLayer.path = CGPath(ellipseIn: rect, transform: nil)

        self.layer?.mask = maskLayer
        self.maskLayer = maskLayer

        // Add shadow to circular shape
        self.layer?.shadowPath = maskLayer.path
        self.layer?.shadowColor = NSColor.black.cgColor
        self.layer?.shadowOpacity = 0.5
        self.layer?.shadowRadius = 10
        self.layer?.shadowOffset = CGSize(width: 0, height: -5)
    }
}
```

### 4. Video Preview Integration

```swift
func setupVideoPreview() {
    guard let previewLayer = cameraManager.previewLayer else { return }

    // Configure preview layer
    previewLayer.frame = circularView.bounds
    previewLayer.videoGravity = .resizeAspectFill  // Fill circle, crop edges

    // Add to content view
    circularView.layer?.insertSublayer(previewLayer, at: 0)

    // Start camera
    cameraManager.startSession()
}
```

**Important:** Insert preview layer at index 0 (back), so mask applies on top.

### 5. Video Gravity Options

```swift
// Options for previewLayer.videoGravity
.resizeAspectFill   // ✅ Use this - fills circle, crops edges
.resizeAspect       // ❌ Letterboxing (black bars)
.resize             // ❌ Stretches video
```

### 6. Window Dragging

Window is draggable by default with `isMovableByWindowBackground = true`.

**Behavior:**
- Click and drag anywhere in circle to move window
- Window follows cursor
- Position persists (see design/05-preferences.md)

## Layout Behavior

### Circular Shape Enforcement

Always maintain perfect circle:

```swift
override func setFrame(_ frameRect: NSRect, display flag: Bool) {
    // Enforce square frame (width == height)
    let size = min(frameRect.width, frameRect.height)
    let squareFrame = NSRect(
        origin: frameRect.origin,
        size: CGSize(width: size, height: size)
    )
    super.setFrame(squareFrame, display: flag)
}
```

### Resizing (See design/04-resize-interaction.md)
- Resize by dragging edges (implemented later)
- Always maintain circular shape during resize

## Visual Appearance

### Color Scheme
- **Inside circle:** Camera feed
- **Outside circle:** Transparent (see-through to desktop)
- **Border:** None (clean edge)
- **Shadow:** Subtle drop shadow for depth

### Sizing
- **Default:** 200x200 points
- **Minimum:** 100x100 points (too small is not useful)
- **Maximum:** 600x600 points (too large is intrusive)
- **Resize:** User can resize (see design/04)

## Window Lifecycle

### Show
```swift
func show() {
    self.orderFrontRegardless()  // Bring to front, even if not active app
    cameraManager.startSession()
}
```

### Hide
```swift
func hide() {
    self.orderOut(nil)  // Hide window
    cameraManager.stopSession()  // Save resources
}
```

### Close vs Hide
- **Don't** close window when user clicks menu bar icon
- **Do** hide window (preserve state)
- App continues running in menu bar

## Multi-Monitor Support

### Initial Placement
```swift
// Place on main screen by default
let screen = NSScreen.main ?? NSScreen.screens[0]
```

### Moving Between Screens
- User can drag window to any screen
- Window position persists per-screen (see design/05)

### Edge Cases
- **Screen disconnected:** Window moves to main screen
- **Screen resolution changed:** Keep window visible (adjust if needed)

## Layer Hierarchy

```
CircularWindow
└── CircularContentView (contentView)
    └── layer
        ├── AVCaptureVideoPreviewLayer (at index 0, back)
        └── mask (CAShapeLayer, circular)
```

**Order matters:** Preview layer must be at index 0 for mask to apply correctly.

## Testing Checklist

### Visual
- [ ] Window is perfectly circular
- [ ] No rectangular background visible
- [ ] Camera feed fills circle (no black bars)
- [ ] Smooth edges (no jagged)
- [ ] Drop shadow appears correctly

### Behavior
- [ ] Window stays on top of other apps
- [ ] Window can be dragged by clicking inside circle
- [ ] Window position remembered after hide/show
- [ ] Window visible after moving to different screen
- [ ] Window doesn't go above menu bar

### Performance
- [ ] Smooth video rendering (60fps)
- [ ] No stuttering when dragging window
- [ ] Reasonable CPU usage

### Edge Cases
- [ ] Works on Retina and non-Retina displays
- [ ] Works when menu bar is on different screen
- [ ] Window remains visible after screen sleep/wake
- [ ] Handles screen resolution changes

## Implementation Checklist

- [ ] Create CircularWindow class
- [ ] Create CircularContentView class
- [ ] Configure window properties (transparent, borderless, floating)
- [ ] Implement circular masking with CAShapeLayer
- [ ] Add shadow to circular shape
- [ ] Integrate camera preview layer
- [ ] Set videoGravity to resizeAspectFill
- [ ] Implement show/hide methods
- [ ] Enable window dragging
- [ ] Test on different screen sizes
- [ ] Verify always-on-top behavior

## Common Pitfalls

### 1. Preview Layer Not Visible
**Cause:** Preview layer added after mask, or wrong z-order
**Solution:** Insert at index 0: `layer.insertSublayer(previewLayer, at: 0)`

### 2. Non-Circular Edges
**Cause:** Mask not updating on resize
**Solution:** Update mask in `layout()` method

### 3. Black Bars (Letterboxing)
**Cause:** Wrong videoGravity
**Solution:** Use `.resizeAspectFill`, not `.resizeAspect`

### 4. Window Below Other Apps
**Cause:** Wrong window level
**Solution:** Set `level = .floating`

### 5. Rectangular Background Visible
**Cause:** Opaque window or wrong background color
**Solution:** Set `isOpaque = false`, `backgroundColor = .clear`

### 6. Shadow Shows Rectangle
**Cause:** Shadow not constrained to mask
**Solution:** Set `layer.shadowPath = maskLayer.path`

## Performance Considerations

### Video Rendering
- Use hardware acceleration (default with AVFoundation)
- Preview layer renders efficiently on GPU
- No manual frame-by-frame processing needed

### Mask Performance
- CAShapeLayer mask is GPU-accelerated
- Circular path is simple (fast)
- Update mask only on resize (not every frame)

## Dependencies
- CameraManager (provides preview layer)
- AppKit (NSWindow, NSView)
- AVFoundation (AVCaptureVideoPreviewLayer)
- QuartzCore (CAShapeLayer)

## Next Steps
After circular window works:
- Add menu bar controller (design/03) to show/hide window
- Add resize interaction (design/04) to allow user resizing
- Add preferences (design/05) to persist window size and position
