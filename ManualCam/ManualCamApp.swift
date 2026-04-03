//  ManualCamApp.swift
//  ManualCam

import SwiftUI

@main
struct ManualCamApp: App {
    var body: some Scene {
        WindowGroup {
            ManualCameraView()
                .preferredColorScheme(.dark)
        }
    }
}
