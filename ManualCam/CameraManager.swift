//
//  CameraManager.swift
//  ManualCam
//
//  Created by DB on 4/2/26.
//
import Foundation
import AVFoundation
import SwiftUI
import Photos

class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Session
    let session = AVCaptureSession()
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    
    // MARK: - Published Properties
    @Published var iso: Float = 100
    @Published var shutterSpeed: CMTime = CMTimeMake(value: 1, timescale: 60)
    @Published var focusValue: Float = 0.5
    @Published var whiteBalance: Float = 5000
    @Published var isSessionRunning = false
    @Published var isCapturing = false
    @Published var lastCapturedImage: UIImage?
    @Published var exposureMode: ExposureMode = .auto
    @Published var focusMode: FocusMode = .auto
    @Published var currentLensIndex: Int = 0
    @Published var availableLenses: [AVCaptureDevice] = []
    
    // MARK: - Device Limits
    @Published var minISO: Float = 50
    @Published var maxISO: Float = 1600
    @Published var minShutterSpeed: CMTime = CMTimeMake(value: 1, timescale: 8000)
    @Published var maxShutterSpeed: CMTime = CMTimeMake(value: 1, timescale: 1)
    
    // MARK: - Common Shutter Speeds
    let commonShutterSpeeds: [(String, CMTime)] = [
        ("1/8000", CMTimeMake(value: 1, timescale: 8000)),
        ("1/4000", CMTimeMake(value: 1, timescale: 4000)),
        ("1/2000", CMTimeMake(value: 1, timescale: 2000)),
        ("1/1000", CMTimeMake(value: 1, timescale: 1000)),
        ("1/500",  CMTimeMake(value: 1, timescale: 500)),
        ("1/250",  CMTimeMake(value: 1, timescale: 250)),
        ("1/125",  CMTimeMake(value: 1, timescale: 125)),
        ("1/60",   CMTimeMake(value: 1, timescale: 60)),
        ("1/30",   CMTimeMake(value: 1, timescale: 30)),
        ("1/15",   CMTimeMake(value: 1, timescale: 15)),
        ("1/8",    CMTimeMake(value: 1, timescale: 8)),
        ("1/4",    CMTimeMake(value: 1, timescale: 4)),
        ("1/2",    CMTimeMake(value: 1, timescale: 2)),
        ("1s",     CMTimeMake(value: 1, timescale: 1))
    ]
    
    // MARK: - Enums
    enum ExposureMode: String {
        case auto = "Auto"
        case manual = "Manual"
    }
    
    enum FocusMode: String {
        case auto = "Auto"
        case manual = "Manual"
    }
    
    // MARK: - Init
    override init() {
        super.init()
        setupSession()
    }
    
    // MARK: - Session Setup
    func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
                .builtInTelephotoCamera
            ],
            mediaType: .video,
            position: .back
        )
        availableLenses = discoverySession.devices
        
        guard let camera = availableLenses.first(where: { $0.deviceType == .builtInWideAngleCamera })
                ?? availableLenses.first else {
            print("No camera found")
            session.commitConfiguration()
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                self.input = newInput
                self.device = camera
            }
            
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                photoOutput.isHighResolutionCaptureEnabled = true
                photoOutput.maxPhotoQualityPrioritization = .quality
            }
            
            updateDeviceLimits()
            
        } catch {
            print("Error setting up camera: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = self?.session.isRunning ?? false
            }
        }
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }
    
    // MARK: - Device Limits
    private func updateDeviceLimits() {
        guard let device = device else { return }
        minISO = device.activeFormat.minISO
        maxISO = device.activeFormat.maxISO
        minShutterSpeed = device.activeFormat.minExposureDuration
        maxShutterSpeed = device.activeFormat.maxExposureDuration
        iso = device.iso
        shutterSpeed = device.exposureDuration
        focusValue = device.lensPosition
    }
    
    // MARK: - Manual Exposure
    func setISO(_ newISO: Float) {
        guard let device = device else { return }
        let clamped = max(minISO, min(maxISO, newISO))
        
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: shutterSpeed, iso: clamped) { _ in }
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.iso = clamped
                self.exposureMode = .manual
            }
        } catch {
            print("Error setting ISO: \(error)")
        }
    }
    
    func setShutterSpeed(_ duration: CMTime) {
        guard let device = device else { return }
        let clamped = clampTime(duration)
        
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: clamped, iso: iso) { _ in }
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.shutterSpeed = clamped
                self.exposureMode = .manual
            }
        } catch {
            print("Error setting shutter speed: \(error)")
        }
    }
    
    func setAutoExposure() {
        guard let device = device else { return }
        do {
            try device.lockForConfiguration()
            device.exposureMode = .continuousAutoExposure
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.exposureMode = .auto
            }
        } catch {
            print("Error setting auto exposure: \(error)")
        }
    }
    
    // MARK: - Manual Focus
    func setFocus(_ value: Float) {
        guard let device = device else { return }
        let clamped = max(0.0, min(1.0, value))
        
        do {
            try device.lockForConfiguration()
            device.setFocusModeLocked(lensPosition: clamped) { _ in }
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.focusValue = clamped
                self.focusMode = .manual
            }
        } catch {
            print("Error setting focus: \(error)")
        }
    }
    
    func setAutoFocus() {
        guard let device = device else { return }
        guard device.isFocusModeSupported(.continuousAutoFocus) else { return }
        do {
            try device.lockForConfiguration()
            device.focusMode = .continuousAutoFocus
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.focusMode = .auto
            }
        } catch {
            print("Error setting auto focus: \(error)")
        }
    }
    
    // MARK: - White Balance
    func setWhiteBalance(_ temperature: Float) {
        guard let device = device else { return }
        
        let tempTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
            temperature: temperature,
            tint: 0.0
        )
        var gains = device.deviceWhiteBalanceGains(for: tempTint)
        gains = clampGains(gains)
        
        do {
            try device.lockForConfiguration()
            device.setWhiteBalanceModeLocked(with: gains) { _ in }
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.whiteBalance = temperature
            }
        } catch {
            print("Error setting white balance: \(error)")
        }
    }
    
    func setAutoWhiteBalance() {
        guard let device = device else { return }
        do {
            try device.lockForConfiguration()
            device.whiteBalanceMode = .continuousAutoWhiteBalance
            device.unlockForConfiguration()
        } catch {
            print("Error setting auto WB: \(error)")
        }
    }
    
    private func clampGains(_ gains: AVCaptureDevice.WhiteBalanceGains) -> AVCaptureDevice.WhiteBalanceGains {
        guard let device = device else { return gains }
        var g = gains
        let maxGain = device.maxWhiteBalanceGain
        g.redGain = max(1.0, min(maxGain, g.redGain))
        g.greenGain = max(1.0, min(maxGain, g.greenGain))
        g.blueGain = max(1.0, min(maxGain, g.blueGain))
        return g
    }
    
    // MARK: - Lens Switching
    func switchLens(to index: Int) {
        guard index < availableLenses.count else { return }
        let newDevice = availableLenses[index]
        
        session.beginConfiguration()
        
        if let currentInput = input {
            session.removeInput(currentInput)
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                self.input = newInput
                self.device = newDevice
                updateDeviceLimits()
                DispatchQueue.main.async {
                    self.currentLensIndex = index
                    self.exposureMode = .auto
                    self.focusMode = .auto
                }
            }
        } catch {
            print("Error switching lens: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    func lensName(for device: AVCaptureDevice) -> String {
        switch device.deviceType {
        case .builtInUltraWideCamera: return "0.5x"
        case .builtInWideAngleCamera: return "1x"
        case .builtInTelephotoCamera: return "3x"
        default: return "?"
        }
    }
    
    // MARK: - Photo Capture
    func capturePhoto() {
        guard !isCapturing else { return }
        
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .quality
        
        isCapturing = true
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Display Helpers
    var shutterSpeedString: String {
        let seconds = CMTimeGetSeconds(shutterSpeed)
        if seconds >= 1.0 {
            return String(format: "%.1fs", seconds)
        } else {
            let denom = Int(round(1.0 / seconds))
            return "1/\(denom)"
        }
    }
    
    var isoString: String {
        return "ISO \(Int(iso))"
    }
    
    var whiteBalanceString: String {
        return "\(Int(whiteBalance))K"
    }
    
    // MARK: - Helpers
    private func clampTime(_ time: CMTime) -> CMTime {
        if CMTimeCompare(time, minShutterSpeed) < 0 { return minShutterSpeed }
        if CMTimeCompare(time, maxShutterSpeed) > 0 { return maxShutterSpeed }
        return time
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        DispatchQueue.main.async {
            self.isCapturing = false
        }
        
        if let error = error {
            print("Capture error: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("No image data")
            return
        }
        
        if let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.lastCapturedImage = image
            }
        }
        
        // Save to Photos
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else { return }
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: imageData, options: nil)
            } completionHandler: { success, error in
                if let error = error {
                    print("Save error: \(error)")
                }
            }
        }
    }
}
