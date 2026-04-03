//
//  ZoneSystemView.swift
//  ManualCam
//
//  Created by DB on 4/2/26.
//
import SwiftUI

struct ZoneSystemView: View {
    @ObservedObject var cameraManager: CameraManager
    @Binding var isPresented: Bool
    
    let zones: [(String, String, Color)] = [
        ("0",  "Pure Black",         Color(white: 0.0)),
        ("I",  "Near Black",         Color(white: 0.05)),
        ("II", "Deep Shadow",        Color(white: 0.12)),
        ("III","Dark Shadow",        Color(white: 0.20)),
        ("IV", "Shadow Detail",      Color(white: 0.30)),
        ("V",  "Middle Gray (18%)",  Color(white: 0.42)),
        ("VI", "Light Skin / Sky",   Color(white: 0.56)),
        ("VII","Bright Surface",     Color(white: 0.70)),
        ("VIII","Highlights",        Color(white: 0.85)),
        ("IX", "Near White",         Color(white: 0.95)),
        ("X",  "Pure White",         Color(white: 1.0))
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Zone Strip
                    HStack(spacing: 0) {
                        ForEach(0..<zones.count, id: \.self) { i in
                            Rectangle()
                                .fill(zones[i].2)
                                .frame(height: 60)
                                .overlay(
                                    Text(zones[i].0)
                                        .font(.caption2.bold())
                                        .foregroundColor(i < 5 ? .white : .black)
                                )
                        }
                    }
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Current Exposure Info
                    VStack(spacing: 12) {
                        Text("Current Exposure")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 24) {
                            VStack {
                                Text(cameraManager.shutterSpeedString)
                                    .font(.title3.monospacedDigit())
                                    .foregroundColor(.orange)
                                Text("Shutter")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack {
                                Text(cameraManager.isoString)
                                    .font(.title3.monospacedDigit())
                                    .foregroundColor(.orange)
                                Text("ISO")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack {
                                Text(cameraManager.whiteBalanceString)
                                    .font(.title3.monospacedDigit())
                                    .foregroundColor(.orange)
                                Text("WB")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                    .padding()
                    
                    // Zone Descriptions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Zone System Reference")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.bottom, 4)
                        
                        ForEach(0..<zones.count, id: \.self) { i in
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(zones[i].2)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(zones[i].0)
                                            .font(.caption.bold())
                                            .foregroundColor(i < 5 ? .white : .black)
                                    )
                                
                                VStack(alignment: .leading) {
                                    Text("Zone \(zones[i].0)")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                    Text(zones[i].1)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(zoneAdvice(i))
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    
                    // EV Guide
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exposure Compensation Guide")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.bottom, 4)
                        
                        Text("Each zone = 1 stop of light")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Text("To place a subject in a different zone, adjust ISO or shutter speed by the number of stops between zones.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            evRow("Meter reads Zone V → want Zone III", "Close 2 stops (↑ shutter or ↓ ISO)")
                            evRow("Meter reads Zone V → want Zone VII", "Open 2 stops (↓ shutter or ↑ ISO)")
                            evRow("1 stop =", "Double or halve ISO, or double/halve shutter speed")
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color.black)
            .navigationTitle("Zone System")
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
    
    private func zoneAdvice(_ index: Int) -> String {
        switch index {
        case 0: return "No detail — absolute black"
        case 1: return "Slight tonality, no texture"
        case 2: return "First hint of texture in shadows"
        case 3: return "Dark fabrics, dark foliage"
        case 4: return "Landscape shadow, dark skin"
        case 5: return "18% gray card, key reference"
        case 6: return "Caucasian skin, clear sky"
        case 7: return "Light surfaces, bright skin"
        case 8: return "Brightest textured white"
        case 9: return "Slight tone, almost white"
        case 10: return "No detail — pure white"
        default: return ""
        }
    }
    
    private func evRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white)
            Text(value)
                .font(.caption2)
                .foregroundColor(.orange)
        }
        .padding(.vertical, 2)
    }
}
