//
//  ToolBarView.swift
//  LiveStreamer
//
//  Created by HingTatTsang on 7/21/23.
//

import SwiftUI

struct ToolBarView: View {
    @Binding var sheetOpen: [Bool]
    @ObservedObject var streamManager = StreamManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: App Brand & Badge
            HStack(spacing: 8) {
                Image(systemName: "video.badge.waveform.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("LiveStreamer")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("SWITCHER")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Center: Status Indicators & Studio Clock
            HStack(spacing: 12) {
                // Live Indicator
                if streamManager.isStreaming {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("LIVE \(formatDuration(streamManager.streamDuration))")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(6)
                }
                
                // Rec Indicator
                if streamManager.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                        Text("REC \(formatDuration(streamManager.recordingDuration))")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.6))
                    .cornerRadius(6)
                }
                
                // External Display Indicator
                if streamManager.isExternalScreenConnected {
                    HStack(spacing: 4) {
                        Image(systemName: "airplayvideo")
                            .font(.caption2)
                        Text(streamManager.externalScreenName.uppercased())
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                
                // Studio Clock
                TimeView()
            }
            
            Spacer()
            
            // Right: AirPlay & Settings
            HStack(spacing: 12) {
                // AirPlay route picker button
                AirPlayRoutePicker()
                    .frame(width: 32, height: 32)
                
                Button(action: {
                    if !sheetOpen.isEmpty {
                        sheetOpen[0] = true
                    }
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .padding(6)
                        .background(Color(white: 0.15))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.08))
    }
}
