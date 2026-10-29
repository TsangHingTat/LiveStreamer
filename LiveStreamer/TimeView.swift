//
//  TimeView.swift
//  LiveStreamer
//
//  Created by HingTatTsang on 7/19/23.
//

import SwiftUI
import AVKit

// MARK: - Leak-Free Studio Clock View

struct TimeView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            Text(context.date.formatted(date: .omitted, time: .standard))
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.4))
                .cornerRadius(6)
        }
    }
}

// MARK: - Duration Timer Formatter

func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    let seconds = Int(duration) % 60
    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - AirPlay Route Picker Representable

struct AirPlayRoutePicker: UIViewRepresentable {
    var tintColor: UIColor = .white
    var activeTintColor: UIColor = .systemBlue
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePicker = AVRoutePickerView()
        routePicker.tintColor = tintColor
        routePicker.activeTintColor = activeTintColor
        routePicker.prioritizesVideoDevices = true
        return routePicker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tintColor
        uiView.activeTintColor = activeTintColor
    }
}
