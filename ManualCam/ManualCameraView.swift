//
//  ManualCameraView.swift
//  ManualCam
//
//  Created by DB on 4/2/26.
//

import SwiftUI
import AVFoundation

struct ManualCameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showZoneSystem = false
    @State private var showSettings = false
    @State private var activeControl: ControlType = .none
    @State private var showLastPhoto = false
    
    enum ControlType {
        case none, iso, shutter, focus, whiteBalance
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                topBar
                
                // Camera Preview
                ZStack {
                    CameraPreview(session: cameraManager.session)
                        .ignoresSafeArea(edges: .horizontal)
                    
                    // Grid Overlay
                    gridOverlay
                    
                    // Tap to focus indicator
                    if cameraManager.focusMode == .auto {
                        Text("Tap preview to focus")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(6)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                
                // Exposure Info Bar
                exposureInfoBar
                
                // Active Control Slider
                if activeControl != .none {
                    activeControlView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Control Buttons
                controlButtons
                
                // Bottom Bar (Capture)
                bottomBar
            }
        }
        .animation(.easeInOut(duration: 0.2), value: activeControl)
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showZoneSystem) {
            ZoneSystemView(cameraManager: cameraManager, isPresented: $showZoneSystem)
        }
        .sheet(isPresented: $showLastPhoto) {
            if let image = cameraManager.lastCapturedImage {
                PhotoReviewView(image: image, isPresented: $showLastPhoto)
            }
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            // Zone System Button
            Button(action: { showZoneSystem = true }) {
                VStack(spacing: 2) {
                    Image(systemName: "camera.metering.matrix")
                        .font(.system(size: 20))
                    Text("Zones")
                        .font(.system(size: 9))
                }
                .foregroundColor(.orange)
            }
            
            Spacer()
            
            // Exposure Mode
            Button(action: {
                if cameraManager.exposureMode == .auto {
                    cameraManager.setISO(cameraManager.iso)
                } else {
                    cameraManager.setAutoExposure()
                }
            }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(cameraManager.exposureMode == .auto ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(cameraManager.exposureMode == .auto ? "AE" : "ME")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.15))
                .cornerRadius(6)
            }
            
            // Focus Mode
            Button(action: {
                if cameraManager.focusMode == .auto {
                    cameraManager.setFocus(cameraManager.focusValue)
                } else {
                    cameraManager.setAutoFocus()
                }
            }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(cameraManager.focusMode == .auto ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(cameraManager.focusMode == .auto ? "AF" : "MF")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.15))
                .cornerRadius(6)
            }
            
            Spacer()
            
            // Lens Picker
            if cameraManager.availableLenses.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<cameraManager.availableLenses.count, id: \.self) { i in
                        Button(action: { cameraManager.switchLens(to: i) }) {
                            Text(cameraManager.lensName(for: cameraManager.availableLenses[i]))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(i == cameraManager.currentLensIndex ? .black : .white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    i == cameraManager.currentLensIndex
                                    ? Color.orange
                                    : Color.white.opacity(0.15)
                                )
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black)
    }
    
    // MARK: - Grid Overlay
    private var gridOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            Path { path in
                // Vertical lines (rule of thirds)
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                
                // Horizontal lines
                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Exposure Info Bar
    private var exposureInfoBar: some View {
        HStack(spacing: 16) {
            Label(cameraManager.shutterSpeedString, systemImage: "timer")
                .font(.system(size: 12, design: .monospaced))
            
            Label(cameraManager.isoString, systemImage: "camera.aperture")
                .font(.system(size: 12, design: .monospaced))
            
            Label(String(format: "f/%.1f", cameraManager.focusValue), systemImage: "scope")
                .font(.system(size: 12, design: .monospaced))
            
            Label(cameraManager.whiteBalanceString, systemImage: "thermometer.medium")
                .font(.system(size: 12, design: .monospaced))
        }
        .foregroundColor(.white.opacity(0.8))
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Control Buttons
    private var controlButtons: some View {
        HStack(spacing: 0) {
            controlButton("Shutter", icon: "timer", type: .shutter)
            controlButton("ISO", icon: "camera.aperture", type: .iso)
            controlButton("Focus", icon: "scope", type: .focus)
            controlButton("WB", icon: "thermometer.medium", type: .whiteBalance)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.black)
    }
    
    private func controlButton(_ title: String, icon: String, type: ControlType) -> some View {
        Button(action: {
            withAnimation {
                activeControl = activeControl == type ? .none : type
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(activeControl == type ? .orange : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }
    
    // MARK: - Active Control View
    @ViewBuilder
    private var activeControlView: some View {
        VStack(spacing: 8) {
            switch activeControl {
            case .iso:
                Text("ISO: \(Int(cameraManager.iso))")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.orange)
                Slider(
                    value: Binding(
                        get: { cameraManager.iso },
                        set: { cameraManager.setISO($0) }
                    ),
                    in: cameraManager.minISO...cameraManager.maxISO,
                    step: 1
                )
                .accentColor(.orange)
                
            case .shutter:
                Text("Shutter: \(cameraManager.shutterSpeedString)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.orange)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<cameraManager.commonShutterSpeeds.count, id: \.self) { i in
                            let speed = cameraManager.commonShutterSpeeds[i]
                            Button(action: {
                                cameraManager.setShutterSpeed(speed.1)
                            }) {
                                Text(speed.0)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(isCurrentShutter(speed.1) ? .black : .white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        isCurrentShutter(speed.1)
                                        ? Color.orange
                                        : Color.white.opacity(0.15)
                                    )
                                    .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
            case .focus:
                Text("Focus: \(String(format: "%.2f", cameraManager.focusValue))")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.orange)
                Slider(
                    value: Binding(
                        get: { cameraManager.focusValue },
                        set: { cameraManager.setFocus($0) }
                    ),
                    in: 0...1,
                    step: 0.01
                )
                .accentColor(.orange)
                
            case .whiteBalance:
                Text("WB: \(Int(cameraManager.whiteBalance))K")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.orange)
                Slider(
                    value: Binding(
                        get: { cameraManager.whiteBalance },
                        set: { cameraManager.setWhiteBalance($0) }
                    ),
                    in: 2000...10000,
                    step: 100
                )
                .accentColor(.orange)
                HStack {
                    Text("🕯 Warm")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Spacer()
                    Button("Auto") {
                        cameraManager.setAutoWhiteBalance()
                    }
                    .font(.caption2)
                    .foregroundColor(.orange)
                    Spacer()
                    Text("Cool 🌥")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                }
                
            case .none:
                EmptyView()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.9))
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack {
            // Last Photo Thumbnail
            Button(action: { showLastPhoto = true }) {
                if let image = cameraManager.lastCapturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
            }
            
            Spacer()
            
            // Capture Button
            Button(action: { cameraManager.capturePhoto() }) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 70, height: 70)
                    Circle()
                        .fill(cameraManager.isCapturing ? Color.gray : Color.white)
                        .frame(width: 60, height: 60)
                }
            }
            .disabled(cameraManager.isCapturing)
            
            Spacer()
            
            // Placeholder for balance
            Rectangle()
                .fill(Color.clear)
                .frame(width: 50, height: 50)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black)
    }
    
    // MARK: - Helpers
    private func isCurrentShutter(_ time: CMTime) -> Bool {
        let current = CMTimeGetSeconds(cameraManager.shutterSpeed)
        let compare = CMTimeGetSeconds(time)
        return abs(current - compare) / max(compare, 0.0001) < 0.1
    }
}

// MARK: - Photo Review
struct PhotoReviewView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .navigationTitle("Last Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }
}
