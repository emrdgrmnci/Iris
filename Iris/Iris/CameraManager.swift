import Foundation
import AVFoundation

enum CameraError: Error, LocalizedError {
    case noDeviceAvailable
    case permissionDenied
    case cannotAddInput
    case sessionConfigurationFailed

    var errorDescription: String? {
        switch self {
        case .noDeviceAvailable:
            return "No camera device found. Please connect a camera."
        case .permissionDenied:
            return "Iris needs camera access. Enable it in System Settings > Privacy & Security > Camera."
        case .cannotAddInput:
            return "Cannot configure camera."
        case .sessionConfigurationFailed:
            return "Failed to configure camera session."
        }
    }
}

class CameraManager: NSObject {

    // MARK: - Properties
    private var captureSession: AVCaptureSession?
    private var videoDevice: AVCaptureDevice?
    private var videoInput: AVCaptureDeviceInput?

    var previewLayer: AVCaptureVideoPreviewLayer?
    var isSessionRunning: Bool { captureSession?.isRunning ?? false }
    var currentDevice: AVCaptureDevice? { videoDevice }

    // MARK: - Setup
    func setup(with device: AVCaptureDevice?) async throws {
        // Check permissions first
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw CameraError.permissionDenied
            }
        case .denied, .restricted:
            throw CameraError.permissionDenied
        @unknown default:
            throw CameraError.permissionDenied
        }

        // Create session
        let session = AVCaptureSession()
        session.beginConfiguration()

        // Get video device
        let selectedDevice: AVCaptureDevice?
        if let device = device {
            selectedDevice = device
        } else if let savedDeviceID = PreferencesManager.shared.selectedCameraID {
            // Try to restore saved camera
            selectedDevice = Self.availableCameras().first { $0.uniqueID == savedDeviceID }
                ?? AVCaptureDevice.default(for: .video)
        } else {
            selectedDevice = AVCaptureDevice.default(for: .video)
        }

        guard let videoDevice = selectedDevice else {
            session.commitConfiguration()
            throw CameraError.noDeviceAvailable
        }

        // Create input
        let input = try AVCaptureDeviceInput(device: videoDevice)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
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

        // Save selected camera
        PreferencesManager.shared.selectedCameraID = videoDevice.uniqueID
    }

    // MARK: - Session Control
    func startSession() {
        guard let session = captureSession, !session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func stopSession() {
        guard let session = captureSession, session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }

    // MARK: - Device Enumeration
    static func availableCameras() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }

    // MARK: - Device Switching
    func switchToCamera(_ device: AVCaptureDevice) async throws {
        guard let session = captureSession else { return }

        let wasRunning = session.isRunning
        if wasRunning {
            stopSession()
            // Wait a bit for session to stop
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        session.beginConfiguration()

        // Remove old input
        if let oldInput = videoInput {
            session.removeInput(oldInput)
        }

        // Add new input
        let newInput = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(newInput) else {
            // Try to restore old input
            if let oldInput = videoInput, session.canAddInput(oldInput) {
                session.addInput(oldInput)
            }
            session.commitConfiguration()
            throw CameraError.cannotAddInput
        }
        session.addInput(newInput)

        session.commitConfiguration()

        // Update references
        self.videoDevice = device
        self.videoInput = newInput

        // Save preference
        PreferencesManager.shared.selectedCameraID = device.uniqueID

        if wasRunning {
            startSession()
        }
    }
}
