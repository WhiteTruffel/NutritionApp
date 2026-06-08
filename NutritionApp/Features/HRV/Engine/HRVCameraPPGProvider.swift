import Foundation
import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
import CoreGraphics

/// Real fingertip PPG capture using the rear camera with the torch on.
///
/// Device only: the iOS Simulator has no usable camera, so `HRVScanRunner`
/// substitutes the simulated provider there and under the automation flag. The
/// numeric work (waveform to RR intervals) lives in the unit-tested
/// `HRVPPGSignalProcessor`; this class is the thin AVFoundation shell that turns
/// the torch on and averages the red channel of each frame into a brightness
/// series.
///
/// Camera permission relies on the app's existing `NSCameraUsageDescription`.
final class HRVCameraPPGProvider: NSObject, HRVCaptureProvider,
                                  AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    enum CaptureError: Error { case cameraUnavailable, accessDenied, notEnoughSignal }

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue(label: "hrv.ppg.samples")
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
    private var device: AVCaptureDevice?

    // Mutated only on `sampleQueue`.
    private var brightness: [Double] = []
    private var timestamps: [Double] = []
    private var collecting = false

    // MARK: - HRVCaptureProvider

    func capture(mode: HRVScanMode) async throws -> HRVCapturedIntervals {
        try await ensureCameraAccess()
        try configureSession()
        defer { teardown() }

        startCollecting()
        session.startRunning()
        let duration = mode.captureDurationSeconds
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        stopCollecting()

        let (b, t) = snapshot()
        let intervals = HRVPPGSignalProcessor.intervalsMs(brightness: b, timestamps: t)
        guard intervals.count >= 5 else { throw CaptureError.notEnoughSignal }
        return HRVCapturedIntervals(rawIntervalsMs: intervals, durationSeconds: duration, source: .cameraPPG)
    }

    // MARK: - Permission

    private func ensureCameraAccess() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { throw CaptureError.accessDenied }
        default:
            throw CaptureError.accessDenied
        }
    }

    // MARK: - Session setup / teardown

    private func configureSession() throws {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            throw CaptureError.cameraUnavailable
        }
        device = camera

        session.beginConfiguration()
        session.sessionPreset = .low   // we only need average brightness; low res is fast
        if session.canAddInput(input) { session.addInput(input) }
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sampleQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        session.commitConfiguration()

        // Torch on for a stable, well-lit pulse signal.
        if camera.hasTorch, camera.isTorchAvailable,
           (try? camera.lockForConfiguration()) != nil {
            try? camera.setTorchModeOn(level: 1.0)
            camera.unlockForConfiguration()
        }
    }

    private func teardown() {
        if session.isRunning { session.stopRunning() }
        if let device, device.hasTorch, (try? device.lockForConfiguration()) != nil {
            device.torchMode = .off
            device.unlockForConfiguration()
        }
    }

    // MARK: - Sample collection (all on sampleQueue)

    private func startCollecting() {
        sampleQueue.sync {
            brightness.removeAll(keepingCapacity: true)
            timestamps.removeAll(keepingCapacity: true)
            collecting = true
        }
    }

    private func stopCollecting() {
        sampleQueue.sync { collecting = false }
    }

    private func snapshot() -> ([Double], [Double]) {
        sampleQueue.sync { (brightness, timestamps) }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard collecting, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        guard ts.isFinite else { return }

        // Average the whole frame to one RGBA pixel and read the red channel.
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let averaged = ciImage.applyingFilter(
            "CIAreaAverage",
            parameters: [kCIInputExtentKey: CIVector(cgRect: ciImage.extent)])
        var rgba = [UInt8](repeating: 0, count: 4)
        ciContext.render(averaged,
                         toBitmap: &rgba,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())

        // Already on sampleQueue, so direct append is safe.
        brightness.append(Double(rgba[0]))
        timestamps.append(ts)
    }
}
