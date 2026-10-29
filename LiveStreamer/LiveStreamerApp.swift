//
//  LiveStreamerApp.swift
//  LiveStreamer
//
//  Created by HingTatTsang on 7/19/23.
//

import SwiftUI
import UIKit
import Combine

@main
struct LiveStreamerApp: App {
    @StateObject private var streamManager = StreamManager.shared
    @State private var additionalWindows: [UIWindow] = []
    
    private var screenDidConnectPublisher: AnyPublisher<UIScreen, Never> {
        NotificationCenter.default
            .publisher(for: UIScreen.didConnectNotification)
            .compactMap { $0.object as? UIScreen }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    private var screenDidDisconnectPublisher: AnyPublisher<UIScreen, Never> {
        NotificationCenter.default
            .publisher(for: UIScreen.didDisconnectNotification)
            .compactMap { $0.object as? UIScreen }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(streamManager)
                .onReceive(screenDidConnectPublisher, perform: screenDidConnect)
                .onReceive(screenDidDisconnectPublisher, perform: screenDidDisconnect)
                .onAppear {
                    checkForAlreadyConnectedScreens()
                }
        }
    }
    
    // MARK: - External Screen / AirPlay Management
    
    private func checkForAlreadyConnectedScreens() {
        // If an external screen is already connected at launch
        let externalScreens = UIScreen.screens.filter { $0 != UIScreen.main }
        for screen in externalScreens {
            screenDidConnect(screen)
        }
    }
    
    private func screenDidConnect(_ screen: UIScreen) {
        guard screen != UIScreen.main else { return }
        
        let window = UIWindow(frame: screen.bounds)
        window.windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.screen == screen }
        
        // Host the live program canvas directly without any intermediary rasterization or UserDefaults!
        let programOutputView = ExternalProgramOutputView()
            .environmentObject(streamManager)
        let controller = UIHostingController(rootView: programOutputView)
        controller.view.backgroundColor = .black
        window.rootViewController = controller
        window.isHidden = false
        additionalWindows.append(window)
        
        streamManager.isExternalScreenConnected = true
        let width = Int(screen.bounds.width)
        let height = Int(screen.bounds.height)
        streamManager.externalScreenName = "\(width)x\(height)"
        streamManager.showToast("📺 EXTERNAL DISPLAY CONNECTED (\(width)x\(height))")
    }

    private func screenDidDisconnect(_ screen: UIScreen) {
        additionalWindows.removeAll { $0.screen == screen }
        if additionalWindows.isEmpty {
            streamManager.isExternalScreenConnected = false
            streamManager.externalScreenName = "None"
            streamManager.showToast("EXTERNAL DISPLAY DISCONNECTED")
        }
    }
}

// MARK: - Dedicated External Display / AirPlay Program Output

struct ExternalProgramOutputView: View {
    @ObservedObject var streamManager = StreamManager.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Real-time declarative rendering of program scene
            SceneCanvasView(
                scene: streamManager.programScene,
                isInteractive: false
            )
        }
    }
}
