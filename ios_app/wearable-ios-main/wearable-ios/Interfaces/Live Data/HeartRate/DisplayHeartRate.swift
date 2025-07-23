//
//  DisplayHeartRate.swift
//  wearable-ios
//
//  Created by Luke Redmore on 9/26/24.
//

import SwiftUI
import Combine

/// Heart icon and bpm label that animates to the given BPM
struct DisplayHeartRate: View {
    @State private var scale: CGFloat = 1.0
    var bpm: Int?
        
    var body: some View {
        HStack {
            Spacer()
            HStack {
                if let bpm = bpm {
                    VStack(spacing: -10) {
                        // Heart rate value
                        Text("\(bpm)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1) // Allow only 1 line for the text
                            .minimumScaleFactor(0.5)
                        
                        // BPM label
                        Text("BPM")
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center) // Center text alignment
                    .padding(.leading, 10)
                    
                    
                    // Heart icon that pulses
                    Image(systemName: "heart.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 65, height: 65) // Adjust size as needed
                        .foregroundColor(.red)
                        .scaleEffect(scale)
                        .modifier(PulseEffect(bpm: bpm))
                } else {
                    ProgressView()
                }
            }
            .frame(width: 150.0)
            Spacer()
        }.frame(height: 75.0)
    }
    
    // Pulse effect as a custom ViewModifier
    struct PulseEffect: ViewModifier {
        var bpm: Int
        @State private var scale: CGFloat = 1.0
        @State private var timer: Publishers.Autoconnect<Timer.TimerPublisher>? = nil
        
        func body(content: Content) -> some View {
            content
                .scaleEffect(scale)
                .onAppear {
                    startPulse(bpm: bpm)
                }
                .onChange(of: bpm) { _, newValue in
                    startPulse(bpm: newValue)
                }
                .onReceive(timer ?? Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                    animatePulse()
                }
        }
        
        @MainActor
        private func startPulse(bpm: Int) {
            let pulseDuration = 60.0 / Double(bpm)
            timer = Timer.publish(every: pulseDuration, on: .main, in: .common).autoconnect()
        }
        
        @MainActor
        private func animatePulse() {
            // Step 1: Rapidly scale up (pulse)
            withAnimation(Animation.easeInOut(duration: 0.25)) {
                scale = 1.15
            }
            // Step 2: Quickly shrink below normal size (overbounce)
            withAnimation(Animation.easeOut(duration: 0.15).delay(0.25)) {
                scale = 0.95
            }
            // Step 3: Bounce back to normal size
            withAnimation(Animation.interpolatingSpring(stiffness: 200, damping: 5).delay(0.25 + 0.15)) {
                scale = 1.0
            }
        }
    }
}

#Preview {
    @Previewable @State var bpm = 120.0
    List {
        DisplayHeartRate(bpm: 60)
        DisplayHeartRate(bpm: Int(bpm.rounded()))
        Slider(value: $bpm, in: 0...150)
        DisplayHeartRate(bpm: nil)
        
    }
}
