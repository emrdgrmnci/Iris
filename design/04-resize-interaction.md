# Design: Resize Interaction

## Overview
Enable users to resize the circular window by dragging from the edges of the circle, while maintaining the circular shape.

## Goals
- Detect mouse position near edge of circle
- Change cursor to resize cursor when near edge
- Handle drag gesture to resize window
- Maintain circular shape during resize
- Enforce minimum and maximum sizes
- Smooth, responsive resizing

## Architecture

### ResizableCircularView Class

```swift
class ResizableCircularView: CircularContentView {
    // MARK: - Properties
    private var isResizing = false
    private var resizeStartPoint: CGPoint?
    private var originalFrame: CGRect?

    private let edgeThreshold: CGFloat = 20  // Points from edge to detect resize

    // MARK: - Mouse Tracking
    override func updateTrackingAreas()
    override func mouseEntered(with event: NSEvent)
    override func mouseMoved(with event: NSEvent)
    override func mouseExited(with event: NSEvent)
    override func mouseDown(with event: NSEvent)
    override func mouseDragged(with event: NSEvent)
    override func mouseUp(with event: NSEvent)

    // MARK: - Edge Detection
    func isPointNearEdge(_ point: CGPoint) -> Bool
    func distanceFromCenter(_ point: CGPoint) -> CGFloat
}
```

## Key Components

### 1. Edge Detection

The challenge: Detect if mouse is near the **circular edge**, not rectangular edge.

```swift
func isPointNearEdge(_ point: CGPoint) -> Bool {
    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let radius = min(bounds.width, bounds.height) / 2

    let distance = distanceFromCenter(point)

    // Near edge if distance is within threshold of radius
    let innerRadius = radius - edgeThreshold
    return distance >= innerRadius && distance <= radius + edgeThreshold
}

func distanceFromCenter(_ point: CGPoint) -> CGFloat {
    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let dx = point.x - center.x
    let dy = point.y - center.y
    return sqrt(dx * dx + dy * dy)
}
```

**Visual:**
```
    ┌─────────────────┐
    │                 │
    │    ●────○       │  ○ = Edge point (trigger resize)
    │    │  R │       │  ● = Center
    │    │    │       │  R = Radius
    │    ○────┘       │  Shaded area = Resize zone
    │                 │
    └─────────────────┘
```

### 2. Cursor Management

```swift
override func updateTrackingAreas() {
    // Remove old tracking areas
    trackingAreas.forEach { removeTrackingArea($0) }

    // Add new tracking area covering entire view
    let trackingArea = NSTrackingArea(
        rect: bounds,
        options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
        owner: self,
        userInfo: nil
    )
    addTrackingArea(trackingArea)
}

override func mouseMoved(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)

    if isPointNearEdge(point) {
        // Show resize cursor
        NSCursor.crosshair.set()
        // Or use: NSCursor.arrow.set() and show custom resize affordance
    } else {
        // Normal cursor
        NSCursor.arrow.set()
    }
}

override func mouseExited(with event: NSEvent) {
    NSCursor.arrow.set()
}
```

**Cursor Options:**
- `.crosshair` - Cross hair cursor
- Custom resize cursor (4-way arrows)
- Visual ring on edge (instead of cursor change)

### 3. Resize Gesture Handling

```swift
override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)

    if isPointNearEdge(point) {
        // Start resize
        isResizing = true
        resizeStartPoint = event.locationInWindow
        originalFrame = window?.frame

        // Disable window dragging during resize
        window?.isMovableByWindowBackground = false
    }
}

override func mouseDragged(with event: NSEvent) {
    guard isResizing,
          let startPoint = resizeStartPoint,
          let originalFrame = originalFrame,
          let window = window else { return }

    // Calculate delta from start point
    let currentPoint = event.locationInWindow
    let delta = CGPoint(
        x: currentPoint.x - startPoint.x,
        y: currentPoint.y - startPoint.y
    )

    // Calculate new size
    // Use distance dragged to determine size change
    let dragDistance = sqrt(delta.x * delta.x + delta.y * delta.y)

    // Determine direction (growing or shrinking)
    let isGrowing = delta.x > 0 || delta.y > 0  // Simplification
    let sizeChange = isGrowing ? dragDistance : -dragDistance

    var newSize = originalFrame.width + sizeChange

    // Enforce size limits
    let minSize: CGFloat = 100
    let maxSize: CGFloat = 600
    newSize = max(minSize, min(maxSize, newSize))

    // Calculate new frame (keep center position)
    let centerX = originalFrame.midX
    let centerY = originalFrame.midY
    let newFrame = CGRect(
        x: centerX - newSize / 2,
        y: centerY - newSize / 2,
        width: newSize,
        height: newSize
    )

    // Apply new frame
    window.setFrame(newFrame, display: true, animate: false)
}

override func mouseUp(with event: NSEvent) {
    isResizing = false
    resizeStartPoint = nil
    originalFrame = nil

    // Re-enable window dragging
    window?.isMovableByWindowBackground = true

    // Save new size to preferences
    if let window = window {
        PreferencesManager.shared.windowSize = window.frame.width
    }
}
```

### 4. Alternative: Resize from Specific Anchor

More sophisticated approach - detect which part of edge:

```swift
enum ResizeDirection {
    case topLeft, topRight, bottomLeft, bottomRight
    case top, bottom, left, right
}

func resizeDirection(for point: CGPoint) -> ResizeDirection? {
    guard isPointNearEdge(point) else { return nil }

    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let angle = atan2(point.y - center.y, point.x - center.x)

    // Determine direction based on angle
    // Return appropriate resize direction
}
```

**Trade-off:** More complex, but allows better control of resize direction.

**Recommendation:** Start with simpler approach (resize from anywhere on edge).

### 5. Visual Feedback

#### Option A: Cursor Change Only
- Simple, standard macOS behavior
- No additional UI

#### Option B: Edge Highlight
```swift
override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    if isHoveringEdge {
        // Draw subtle highlight ring on edge
        let radius = min(bounds.width, bounds.height) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        let ring = NSBezierPath()
        ring.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: 360
        )
        ring.lineWidth = 2
        NSColor.white.withAlphaComponent(0.5).setStroke()
        ring.stroke()
    }
}
```

**Recommendation:** Start with cursor change, add visual feedback if needed.

## Size Constraints

### Minimum Size
```swift
let minSize: CGFloat = 100
```
- Below 100px, content becomes too small to be useful
- Camera feed pixelated/unclear
- Hard to interact with

### Maximum Size
```swift
let maxSize: CGFloat = 600
```
- Above 600px, window becomes intrusive
- Takes up too much screen space
- Defeats purpose of "sticky small window"

### Default Size
```swift
let defaultSize: CGFloat = 200
```
- Good balance of visibility and screen space
- Comfortable for most use cases

## Smooth Resizing

### Frame Updates
```swift
// During drag
window.setFrame(newFrame, display: true, animate: false)
//                                        ^^^^^ false for smooth dragging
```

**animate: false** - No animation during drag for immediate feedback.

### Layout Updates
```swift
override func layout() {
    super.layout()

    // Update camera preview layer frame
    if let previewLayer = previewLayer {
        previewLayer.frame = bounds
    }

    // Update circular mask
    updateMask()
}
```

**Automatic:** NSView calls `layout()` when frame changes.

## Aspect Ratio Enforcement

Always maintain 1:1 aspect ratio (perfect circle):

```swift
// In CircularWindow
override func setFrame(_ frameRect: NSRect, display flag: Bool) {
    // Force square
    let size = min(frameRect.width, frameRect.height)
    let squareFrame = NSRect(
        origin: frameRect.origin,
        size: CGSize(width: size, height: size)
    )
    super.setFrame(squareFrame, display: flag)
}
```

## Performance Considerations

### Efficient Hit Testing
- Check edge proximity only on mouse move
- Cache radius calculation if bounds unchanged

### Minimize Layout
- Layout only when frame actually changes
- Avoid unnecessary mask updates

### GPU Acceleration
- Mask and preview layer are GPU-accelerated
- No CPU bottleneck expected

## Testing Checklist

### Edge Detection
- [ ] Cursor changes when near edge
- [ ] Cursor changes around entire circle perimeter
- [ ] Cursor normal when inside circle (not near edge)
- [ ] Edge detection works at different window sizes

### Resizing
- [ ] Drag from edge resizes window
- [ ] Window stays circular during resize
- [ ] Window center stays in same place (grows/shrinks from center)
- [ ] Minimum size enforced (doesn't shrink below 100px)
- [ ] Maximum size enforced (doesn't grow above 600px)
- [ ] Resize is smooth (no stuttering)

### Interaction
- [ ] Can still drag window when not near edge
- [ ] Cannot drag window while resizing
- [ ] Window dragging re-enabled after resize
- [ ] Camera feed stays visible during resize
- [ ] Camera feed scales correctly after resize

### Edge Cases
- [ ] Works on Retina displays
- [ ] Works at different DPI settings
- [ ] Edge detection accurate at minimum size
- [ ] Edge detection accurate at maximum size
- [ ] Resize works when window near screen edge

## Implementation Checklist

- [ ] Create ResizableCircularView (subclass CircularContentView)
- [ ] Implement edge detection logic
- [ ] Add tracking area for mouse events
- [ ] Implement cursor change on edge hover
- [ ] Implement resize gesture handling
- [ ] Enforce size constraints (min/max)
- [ ] Maintain circular shape during resize
- [ ] Disable window drag during resize
- [ ] Save size to preferences after resize
- [ ] Test edge detection accuracy
- [ ] Test resize smoothness

## Common Pitfalls

### 1. Rectangular Edge Detection
❌ **Don't:** Check if point is near rectangular bounds
✅ **Do:** Calculate distance from center, check if near radius

### 2. Window Moves While Resizing
**Cause:** `isMovableByWindowBackground = true` during resize
**Solution:** Set to `false` during resize, restore after

### 3. Resize Not Smooth
**Cause:** `animate: true` in `setFrame`
**Solution:** Use `animate: false` during drag

### 4. Edge Detection Too Sensitive
**Cause:** `edgeThreshold` too large
**Solution:** Use 20px threshold (adjust if needed)

### 5. Oval Instead of Circle
**Cause:** Not enforcing aspect ratio
**Solution:** Always use equal width and height

### 6. Content Doesn't Scale
**Cause:** Preview layer frame not updated
**Solution:** Update layer frame in `layout()`

## Alternative Approaches

### 1. Resize Handle Widget
Add a visible resize handle (e.g., in bottom-right of circle):
- **Pro:** Clear affordance
- **Con:** Always visible, clutters UI

### 2. Resize from Any Point on Edge
Current recommendation - resize from anywhere on edge:
- **Pro:** Easy to discover, no visible UI
- **Con:** Less precise control

### 3. Resize Only from Corners
Resize only from 4 corner points:
- **Pro:** More precise
- **Con:** Harder to discover, circles don't have corners

**Recommendation:** Resize from any edge point (option 2).

## Accessibility

### Keyboard Alternative
Consider adding keyboard shortcut for resize:
- ⌘+ to increase size
- ⌘- to decrease size

```swift
override func keyDown(with event: NSEvent) {
    if event.modifierFlags.contains(.command) {
        if event.charactersIgnoringModifiers == "+" {
            increaseSize()
        } else if event.charactersIgnoringModifiers == "-" {
            decreaseSize()
        }
    }
}
```

## Dependencies
- CircularContentView (base class)
- CircularWindow (for frame manipulation)
- PreferencesManager (to save size)
- AppKit (NSCursor, NSEvent, NSTrackingArea)

## Next Steps
After resize works:
- Add preferences persistence (design/05)
- Save window size preference
- Restore size on app launch
