import Cocoa
import AVFoundation

class CircularWindow: NSWindow {

    // MARK: - Properties
    private let circularView: ResizableCircularView
    private var cameraManager: CameraManager

    // MARK: - Initialization
    init(cameraManager: CameraManager, size: CGFloat = 200) {
        self.cameraManager = cameraManager

        // Calculate initial position
        let savedPosition = PreferencesManager.shared.windowPosition
        let screenRect = NSScreen.main?.visibleFrame ?? .zero

        let origin: CGPoint
        if savedPosition.x > 0 && savedPosition.y > 0 {
            // Verify saved position is on screen
            let savedRect = CGRect(origin: savedPosition, size: CGSize(width: size, height: size))
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(savedRect) }) {
                origin = savedPosition
            } else {
                // Position is off-screen, use center
                origin = CGPoint(
                    x: screenRect.midX - size / 2,
                    y: screenRect.midY - size / 2
                )
            }
        } else {
            // No saved position, use center
            origin = CGPoint(
                x: screenRect.midX - size / 2,
                y: screenRect.midY - size / 2
            )
        }

        let rect = CGRect(origin: origin, size: CGSize(width: size, height: size))

        // Create content view
        self.circularView = ResizableCircularView(frame: NSRect(origin: .zero, size: rect.size))

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

    // MARK: - Window Configuration
    private func configureWindow() {
        // Make window always on top
        self.level = .floating

        // Transparent background
        self.isOpaque = false
        self.backgroundColor = .clear

        // Shadow
        self.hasShadow = true

        // Allow dragging by clicking anywhere in window
        self.isMovableByWindowBackground = true

        // Accept mouse events even when not key window
        self.acceptsMouseMovedEvents = true

        // Set content view
        self.contentView = circularView

        // Observe frame changes to save position
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }

    private func setupVideoPreview() {
        guard let previewLayer = cameraManager.previewLayer else { return }
        circularView.setPreviewLayer(previewLayer)
    }

    // MARK: - Window Lifecycle
    func show() {
        self.orderFrontRegardless()
        cameraManager.startSession()
    }

    func hide() {
        self.orderOut(nil)
        cameraManager.stopSession()
    }

    // MARK: - Frame Enforcement
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        // Enforce square frame (circular shape)
        let size = min(frameRect.width, frameRect.height)
        let squareFrame = NSRect(
            origin: frameRect.origin,
            size: CGSize(width: size, height: size)
        )
        super.setFrame(squareFrame, display: flag)
    }

    // MARK: - Notifications
    @objc private func windowDidMove() {
        PreferencesManager.shared.windowPosition = self.frame.origin
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - ResizableCircularView

class ResizableCircularView: CircularContentView {

    // MARK: - Properties
    private var isResizing = false
    private var resizeStartPoint: CGPoint?
    private var originalWindowFrame: CGRect?
    private var isHoveringEdge = false
    private var cursorPushed = false

    private let edgeThreshold: CGFloat = 15
    private let minSize: CGFloat = 100
    private let maxSize: CGFloat = 600

    // Visual affordance layer
    private var edgeHighlightLayer: CAShapeLayer?

    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTracking()
        setupEdgeHighlight()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupTracking() {
        // Will be set up in updateTrackingAreas
    }

    private func setupEdgeHighlight() {
        edgeHighlightLayer = CAShapeLayer()
        edgeHighlightLayer?.fillColor = nil
        edgeHighlightLayer?.strokeColor = NSColor.white.withAlphaComponent(0.6).cgColor
        edgeHighlightLayer?.lineWidth = 3
        edgeHighlightLayer?.opacity = 0

        if let layer = self.layer {
            layer.addSublayer(edgeHighlightLayer!)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove old tracking areas
        trackingAreas.forEach { removeTrackingArea($0) }

        // Add new tracking area - use .activeAlways to track even when not key window
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways,
            .inVisibleRect
        ]
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func layout() {
        super.layout()

        // Update edge highlight path
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updateEdgeHighlightPath()
        CATransaction.commit()
    }

    private func updateEdgeHighlightPath() {
        let diameter = min(bounds.width, bounds.height)
        let inset: CGFloat = 2
        let rect = CGRect(
            x: (bounds.width - diameter) / 2 + inset,
            y: (bounds.height - diameter) / 2 + inset,
            width: diameter - inset * 2,
            height: diameter - inset * 2
        )
        edgeHighlightLayer?.path = CGPath(ellipseIn: rect, transform: nil)
        edgeHighlightLayer?.frame = bounds
    }

    // MARK: - Mouse Tracking
    override func mouseEntered(with event: NSEvent) {
        // Force cursor update
        window?.invalidateCursorRects(for: self)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let nearEdge = isPointNearEdge(point)

        if nearEdge != isHoveringEdge {
            isHoveringEdge = nearEdge
            updateCursor()
            updateEdgeHighlight()
        }
    }

    override func mouseExited(with event: NSEvent) {
        if isHoveringEdge {
            isHoveringEdge = false
            updateCursor()
            updateEdgeHighlight()
        }
    }

    private func updateCursor() {
        if isHoveringEdge || isResizing {
            if !cursorPushed {
                NSCursor.crosshair.push()
                cursorPushed = true
            }
        } else {
            if cursorPushed {
                NSCursor.pop()
                cursorPushed = false
            }
        }
    }

    private func updateEdgeHighlight() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        edgeHighlightLayer?.opacity = isHoveringEdge ? 1.0 : 0.0
        CATransaction.commit()
    }

    // MARK: - Mouse Events
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if isPointNearEdge(point) {
            // Start resize
            isResizing = true
            // Store the start point in screen coordinates for accurate tracking
            resizeStartPoint = NSEvent.mouseLocation
            originalWindowFrame = window?.frame

            // Disable window dragging during resize
            window?.isMovableByWindowBackground = false

            // Ensure cursor stays as crosshair
            updateCursor()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isResizing,
              let startPoint = resizeStartPoint,
              let originalFrame = originalWindowFrame,
              let window = window else { return }

        // Use screen coordinates for consistent tracking
        let currentPoint = NSEvent.mouseLocation

        // Calculate distance from center of original window to start point
        let originalCenter = CGPoint(x: originalFrame.midX, y: originalFrame.midY)
        let startDistanceFromCenter = sqrt(
            pow(startPoint.x - originalCenter.x, 2) +
            pow(startPoint.y - originalCenter.y, 2)
        )

        // Calculate distance from center to current point
        let currentDistanceFromCenter = sqrt(
            pow(currentPoint.x - originalCenter.x, 2) +
            pow(currentPoint.y - originalCenter.y, 2)
        )

        // The change in radius determines the change in size
        let radiusChange = currentDistanceFromCenter - startDistanceFromCenter
        let sizeChange = radiusChange * 2  // diameter = 2 * radius

        var newSize = originalFrame.width + sizeChange

        // Enforce size limits
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

        // Apply new frame without animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        window.setFrame(newFrame, display: true, animate: false)
        CATransaction.commit()
    }

    override func mouseUp(with event: NSEvent) {
        if isResizing {
            isResizing = false
            resizeStartPoint = nil
            originalWindowFrame = nil

            // Re-enable window dragging
            window?.isMovableByWindowBackground = true

            // Save new size to preferences
            if let window = window {
                PreferencesManager.shared.windowSize = window.frame.width
            }

            // Update cursor state
            let point = convert(event.locationInWindow, from: nil)
            isHoveringEdge = isPointNearEdge(point)
            updateCursor()
        }
    }

    // MARK: - Edge Detection
    private func isPointNearEdge(_ point: CGPoint) -> Bool {
        // First check if point is even in bounds
        guard bounds.contains(point) else { return false }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2

        let distance = distanceFromCenter(point)

        // Near edge if distance is within threshold of radius
        let innerRadius = radius - edgeThreshold
        let outerRadius = radius

        return distance >= innerRadius && distance <= outerRadius
    }

    private func distanceFromCenter(_ point: CGPoint) -> CGFloat {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Cleanup
    deinit {
        if cursorPushed {
            NSCursor.pop()
        }
    }
}
