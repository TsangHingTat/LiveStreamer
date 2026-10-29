//
//  ContentView.swift
//  LiveStreamer
//
//  Created by HingTatTsang on 7/19/23.
//

import SwiftUI
import Photos
import AVKit

struct ContentView: View {
    @StateObject private var streamManager = StreamManager.shared
    
    // UI States
    @State private var sheetOpen = [false] // [0: Settings]
    @State private var isRenameSheetPresented = false
    @State private var sceneToRename: UUID?
    @State private var renameText = ""
    @State private var isAddSourceSheetPresented = false
    @State private var isTakingSnapshot = false
    
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            VStack(spacing: 8) {
                // Top Navigation & Status Bar
                ToolBarView(sheetOpen: $sheetOpen)
                
                // Top Half: Dual Broadcast Monitors (Preview & Program) + Transition Controls
                HStack(spacing: 12) {
                    // Preview Monitor
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("PREVIEW")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.green)
                            Spacer()
                            Text(streamManager.previewScene?.name ?? "No Scene")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        
                        SceneCanvasView(
                            scene: streamManager.previewScene,
                            isInteractive: true,
                            selectedLayerId: streamManager.selectedLayerId,
                            onSelectLayer: { layerId in
                                streamManager.selectedLayerId = layerId
                            },
                            onDragLayer: { layerId, translation in
                                streamManager.updateSelectedLayer { layer in
                                    if layer.id == layerId {
                                        layer.x += translation.width
                                        layer.y += translation.height
                                    }
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.green.opacity(0.8), lineWidth: 2)
                        )
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Center Switcher Controls (ATEM Mini style)
                    VStack(spacing: 12) {
                        Spacer()
                        
                        // CUT Button
                        Button(action: {
                            streamManager.cut()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "forward.fill")
                                    .font(.headline)
                                Text("CUT")
                                    .font(.system(size: 13, weight: .black))
                            }
                            .frame(width: 68, height: 60)
                            .background(
                                LinearGradient(colors: [Color.red.opacity(0.85), Color.red], startPoint: .top, endPoint: .bottom)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: .red.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        
                        // AUTO Transition Button
                        Button(action: {
                            streamManager.autoTransition()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "slider.horizontal.2.square")
                                    .font(.headline)
                                Text("AUTO")
                                    .font(.system(size: 12, weight: .black))
                            }
                            .frame(width: 68, height: 52)
                            .background(Color(white: 0.18))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        // FTB (Fade To Black / Clear) Button
                        Button(action: {
                            streamManager.fadeToBlack()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "circle.slash")
                                    .font(.headline)
                                Text("BLACK")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .frame(width: 68, height: 46)
                            .background(Color.black.opacity(0.8))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.4), lineWidth: 1))
                            .foregroundColor(.gray)
                            .cornerRadius(10)
                        }
                        
                        Spacer()
                    }
                    .frame(width: 76)
                    
                    // Program Monitor (Live On Air)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(streamManager.programSceneId != nil ? Color.red : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(streamManager.programSceneId != nil ? "PROGRAM (ON AIR)" : "PROGRAM (BLACK)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(streamManager.programSceneId != nil ? .red : .gray)
                            Spacer()
                            Text(streamManager.programScene?.name ?? "Blackout")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        
                        SceneCanvasView(
                            scene: streamManager.programScene,
                            isInteractive: false
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(streamManager.programSceneId != nil ? Color.red.opacity(0.85) : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .frame(maxHeight: UIScreen.main.bounds.height * 0.42)
                
                // Bottom Half: Control Deck (4-Column Layout)
                HStack(spacing: 10) {
                    // Column 1: Scenes Bank
                    scenesBankView
                        .frame(maxWidth: .infinity)
                    
                    // Column 2: Sources Bank (for currently previewed scene)
                    sourcesBankView
                        .frame(maxWidth: .infinity)
                    
                    // Column 3: Source Inspector
                    LayerInspectorView()
                        .frame(maxWidth: .infinity)
                    
                    // Column 4: Master Output Controls
                    masterControlsView
                        .frame(width: 175)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            
            // Toast Notification
            if let toast = streamManager.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                        .cornerRadius(20)
                        .shadow(radius: 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 24)
                }
                .animation(.spring(), value: toast)
            }
        }
        // Rename Scene Sheet
        .sheet(isPresented: $isRenameSheetPresented) {
            NavigationView {
                VStack(spacing: 16) {
                    TextField("Scene Name", text: $renameText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    
                    Button("Save") {
                        if let id = sceneToRename {
                            streamManager.renameScene(id: id, newName: renameText)
                        }
                        isRenameSheetPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                }
                .padding(.top, 20)
                .navigationTitle("Rename Scene")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        // Settings Sheet
        .sheet(isPresented: $sheetOpen[0]) {
            settingsSheetView
        }
    }
    
    // MARK: - Column 1: Scenes Bank
    
    private var scenesBankView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("SCENES")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
                Button(action: {
                    streamManager.addScene()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(streamManager.scenes) { scene in
                        let isPreview = streamManager.previewSceneId == scene.id
                        let isProgram = streamManager.programSceneId == scene.id
                        
                        Button(action: {
                            streamManager.previewSceneId = scene.id
                            streamManager.selectedLayerId = nil
                        }) {
                            HStack {
                                // Live Program dot
                                if isProgram {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                } else if isPreview {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                }
                                
                                Text(scene.name)
                                    .font(.subheadline)
                                    .fontWeight(isPreview ? .bold : .regular)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(scene.layers.count) layers")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isPreview ? Color.green.opacity(0.2) : Color(white: 0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(isPreview ? Color.green : (isProgram ? Color.red.opacity(0.8) : Color.clear), lineWidth: 1.5)
                                    )
                            )
                        }
                        .contextMenu {
                            Button {
                                renameText = scene.name
                                sceneToRename = scene.id
                                isRenameSheetPresented = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            
                            Button {
                                streamManager.duplicateScene(id: scene.id)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            
                            if streamManager.scenes.count > 1 {
                                Button(role: .destructive) {
                                    streamManager.deleteScene(id: scene.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(8)
        .background(Color(white: 0.08))
        .cornerRadius(12)
    }
    
    // MARK: - Column 2: Sources / Layers Bank
    
    private var sourcesBankView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("SOURCES")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
                
                Menu {
                    ForEach(LayerType.allCases) { type in
                        Button {
                            if let pId = streamManager.previewSceneId {
                                streamManager.addLayer(to: pId, type: type)
                            }
                        } label: {
                            Label(type.rawValue, systemImage: type.iconName)
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            if let pScene = streamManager.previewScene, !pScene.layers.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        // Render in reverse to show top layer first
                        ForEach(Array(pScene.layers.enumerated()).reversed(), id: \.element.id) { index, layer in
                            let isSelected = streamManager.selectedLayerId == layer.id
                            
                            HStack(spacing: 8) {
                                // Visibility Eye Button
                                Button {
                                    streamManager.updateSelectedLayer { _ in }
                                    if let sIdx = streamManager.scenes.firstIndex(where: { $0.id == pScene.id }) {
                                        streamManager.scenes[sIdx].layers[index].isVisible.toggle()
                                    }
                                } label: {
                                    Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash.fill")
                                        .font(.caption)
                                        .foregroundColor(layer.isVisible ? .white : .gray)
                                }
                                
                                Image(systemName: layer.type.iconName)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Text(layer.name)
                                    .font(.caption)
                                    .fontWeight(isSelected ? .bold : .regular)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                // Move Up / Down
                                Button {
                                    streamManager.moveLayerUp(sceneId: pScene.id, layerId: layer.id)
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.caption2)
                                        .foregroundColor(index < pScene.layers.count - 1 ? .gray : .clear)
                                }
                                .disabled(index >= pScene.layers.count - 1)
                                
                                Button {
                                    streamManager.moveLayerDown(sceneId: pScene.id, layerId: layer.id)
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(index > 0 ? .gray : .clear)
                                }
                                .disabled(index <= 0)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? Color.blue.opacity(0.3) : Color(white: 0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                                    )
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                streamManager.selectedLayerId = layer.id
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    streamManager.deleteLayer(sceneId: pScene.id, layerId: layer.id)
                                } label: {
                                    Label("Delete Source", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "square.stack.3d.up.slash")
                        .foregroundColor(.gray)
                    Text("No Sources")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
        .background(Color(white: 0.08))
        .cornerRadius(12)
    }
    
    // MARK: - Column 4: Master Broadcast Controls
    
    private var masterControlsView: some View {
        VStack(spacing: 10) {
            Text("BROADCAST DECK")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
                .padding(.top, 4)
            
            // Streaming Button
            Button(action: {
                streamManager.toggleStreaming()
            }) {
                HStack {
                    Image(systemName: streamManager.isStreaming ? "stop.circle.fill" : "record.circle")
                        .font(.headline)
                    Text(streamManager.isStreaming ? "STOP STREAM" : "START STREAM")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(streamManager.isStreaming ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Recording Button
            Button(action: {
                streamManager.toggleRecording()
            }) {
                HStack {
                    Image(systemName: streamManager.isRecording ? "stop.fill" : "record.circle.fill")
                        .font(.headline)
                    Text(streamManager.isRecording ? "STOP REC" : "START REC")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(streamManager.isRecording ? Color.red.opacity(0.85) : Color(white: 0.2))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Snapshot Button
            Button(action: {
                captureAndSaveSnapshot()
            }) {
                HStack {
                    if isTakingSnapshot {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "camera.viewfinder")
                            .font(.headline)
                    }
                    Text("PHOTO SNAPSHOT")
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Color(white: 0.16))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isTakingSnapshot)
            
            Spacer()
            
            // Diagnostics
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("CANVAS:")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("1080p 16:9")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.green)
                }
                HStack {
                    Text("FPS:")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("60 FPS")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                }
                HStack {
                    Text("EXT DISPLAY:")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(streamManager.isExternalScreenConnected ? "CONNECTED" : "OFFLINE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(streamManager.isExternalScreenConnected ? .blue : .gray)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.3))
            .cornerRadius(6)
        }
        .padding(8)
        .background(Color(white: 0.08))
        .cornerRadius(12)
    }
    
    // MARK: - Snapshot Capture (High Performance)
    
    @MainActor
    private func captureAndSaveSnapshot() {
        guard let pScene = streamManager.programScene ?? streamManager.previewScene else { return }
        isTakingSnapshot = true
        
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content:
                SceneCanvasView(scene: pScene, isInteractive: false)
                    .frame(width: 1920, height: 1080)
            )
            renderer.scale = 1.0
            
            if let uiImage = renderer.uiImage {
                saveSnapshotImage(uiImage)
            } else {
                isTakingSnapshot = false
                streamManager.showToast("FAILED TO CAPTURE SNAPSHOT")
            }
        } else {
            let controller = UIHostingController(
                rootView: SceneCanvasView(scene: pScene, isInteractive: false)
                    .frame(width: 1920, height: 1080)
            )
            let targetSize = CGSize(width: 1920, height: 1080)
            controller.view.bounds = CGRect(origin: .zero, size: targetSize)
            controller.view.backgroundColor = .black
            
            let window = UIWindow(frame: CGRect(origin: .zero, size: targetSize))
            window.rootViewController = controller
            window.isHidden = false
            
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let image = renderer.image { _ in
                controller.view.drawHierarchy(in: CGRect(origin: .zero, size: targetSize), afterScreenUpdates: true)
            }
            window.isHidden = true
            saveSnapshotImage(image)
        }
    }
    
    @MainActor
    private func saveSnapshotImage(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                self.isTakingSnapshot = false
                if status == .authorized || status == .limited {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    streamManager.showToast("📸 SNAPSHOT SAVED TO PHOTOS")
                } else {
                    streamManager.showToast("⚠️ PHOTO LIBRARY ACCESS DENIED")
                }
            }
        }
    }
    
    // MARK: - Settings Sheet View
    
    private var settingsSheetView: some View {
        NavigationView {
            Form {
                Section(header: Text("Video Output")) {
                    HStack {
                        Text("Resolution")
                        Spacer()
                        Text("1920 x 1080 (Full HD)")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Aspect Ratio")
                        Spacer()
                        Text("16:9 Widescreen")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Frame Rate")
                        Spacer()
                        Text("60 FPS ProMotion")
                            .foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("External Display / AirPlay")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(streamManager.isExternalScreenConnected ? "Active (\(streamManager.externalScreenName))" : "Disconnected")
                            .foregroundColor(streamManager.isExternalScreenConnected ? .green : .gray)
                    }
                    Text("Connect an HDMI monitor or AirPlay receiver to project Program live output full screen automatically.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section(header: Text("Permissions")) {
                    HStack {
                        Text("Camera")
                        Spacer()
                        Text(CameraService.shared.isAuthorized ? "Granted" : "Denied")
                            .foregroundColor(CameraService.shared.isAuthorized ? .green : .red)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("LiveStreamer")
                        Spacer()
                        Text("v2.0 Optimized Pro")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Studio Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        sheetOpen[0] = false
                    }
                }
            }
        }
    }
}
