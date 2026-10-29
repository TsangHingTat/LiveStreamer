//
//  SenceView.swift
//  LiveStreamer
//
//  Created by HingTatTsang on 7/19/23.
//

import SwiftUI
import UIKit
import AVFoundation
import Photos
import Combine

// MARK: - Layer Types

enum LayerType: String, Codable, CaseIterable, Identifiable {
    case camera = "Camera"
    case text = "Text"
    case color = "Color"
    case image = "Image"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .camera: return "video.fill"
        case .text: return "textformat"
        case .color: return "square.fill"
        case .image: return "photo.fill"
        }
    }
}

// MARK: - Codable Color

struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
    
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: opacity)
    }
    
    init(_ color: Color) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }
    
    init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }
    
    static let white = CodableColor(red: 1, green: 1, blue: 1, opacity: 1)
    static let black = CodableColor(red: 0, green: 0, blue: 0, opacity: 1)
    static let redColor = CodableColor(red: 0.9, green: 0.2, blue: 0.2, opacity: 0.8)
    static let blueColor = CodableColor(red: 0.1, green: 0.45, blue: 0.9, opacity: 0.8)
    static let accent = CodableColor(red: 0.2, green: 0.7, blue: 0.4, opacity: 0.8)
}

// MARK: - Scene Layer Model

struct SceneLayer: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var type: LayerType
    var isVisible: Bool = true
    var isLocked: Bool = false
    
    // Transform
    var x: CGFloat = 0.0          // Offset from center of 16:9 frame
    var y: CGFloat = 0.0
    var scale: CGFloat = 1.0      // Scale factor (0.1 to 3.0)
    var rotation: Double = 0.0    // Degrees (0 to 360)
    var opacity: Double = 1.0     // 0.0 to 1.0
    
    // Text Properties
    var text: String = "Live Title"
    var textColor: CodableColor = .white
    var fontSize: CGFloat = 28.0
    var isBold: Bool = true
    
    // Color Properties
    var backgroundColor: CodableColor = .blueColor
    var width: CGFloat = 280.0
    var height: CGFloat = 80.0
    var cornerRadius: CGFloat = 12.0
    
    // Camera Properties
    var cameraFacingFront: Bool = false
    
    // Image Properties
    var systemIconName: String = "sparkles"
    
    init(
        id: UUID = UUID(),
        name: String,
        type: LayerType,
        isVisible: Bool = true,
        isLocked: Bool = false,
        x: CGFloat = 0.0,
        y: CGFloat = 0.0,
        scale: CGFloat = 1.0,
        rotation: Double = 0.0,
        opacity: Double = 1.0,
        text: String = "Live Title",
        textColor: CodableColor = .white,
        fontSize: CGFloat = 28.0,
        isBold: Bool = true,
        backgroundColor: CodableColor = .blueColor,
        width: CGFloat = 280.0,
        height: CGFloat = 80.0,
        cornerRadius: CGFloat = 12.0,
        cameraFacingFront: Bool = false,
        systemIconName: String = "sparkles"
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.x = x
        self.y = y
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
        self.text = text
        self.textColor = textColor
        self.fontSize = fontSize
        self.isBold = isBold
        self.backgroundColor = backgroundColor
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.cameraFacingFront = cameraFacingFront
        self.systemIconName = systemIconName
    }
}

// MARK: - Live Scene Model

struct LiveScene: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var layers: [SceneLayer] = []
}

// MARK: - Camera Service

@MainActor
final class CameraService: NSObject, ObservableObject {
    static let shared = CameraService()
    
    @Published var isAuthorized: Bool = false
    @Published var isRunning: Bool = false
    @Published var currentPosition: AVCaptureDevice.Position = .back
    
    let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.livestreamer.cameraQueue")
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    private override init() {
        super.init()
        checkAuthorization()
    }
    
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.isAuthorized = granted
                    if granted {
                        self.setupSession()
                    }
                }
            }
        default:
            self.isAuthorized = false
        }
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high
            
            // Setup default camera input
            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: camera) {
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                    self.videoDeviceInput = input
                }
            }
            
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
            
            Task { @MainActor in
                self.isRunning = self.captureSession.isRunning
            }
        }
    }
    
    func switchCamera(to position: AVCaptureDevice.Position) {
        guard position != currentPosition else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            
            if let currentInput = self.videoDeviceInput {
                self.captureSession.removeInput(currentInput)
            }
            
            if let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
               let newInput = try? AVCaptureDeviceInput(device: newCamera) {
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.videoDeviceInput = newInput
                    Task { @MainActor in
                        self.currentPosition = position
                    }
                }
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    func start() {
        guard !captureSession.isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
            Task { @MainActor in
                self?.isRunning = true
            }
        }
    }
    
    func stop() {
        guard captureSession.isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            Task { @MainActor in
                self?.isRunning = false
            }
        }
    }
}

// MARK: - Camera Preview Representable

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraService = CameraService.shared
    
    class VideoPreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }
    }
    
    func makeUIView(context: Context) -> VideoPreviewUIView {
        let view = VideoPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.session = cameraService.captureSession
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewUIView, context: Context) {
        if uiView.previewLayer.session != cameraService.captureSession {
            uiView.previewLayer.session = cameraService.captureSession
        }
    }
}

// MARK: - Stream Manager (Observable State Engine)

@MainActor
final class StreamManager: ObservableObject {
    static let shared = StreamManager()
    
    @Published var scenes: [LiveScene] = []
    @Published var previewSceneId: UUID?
    @Published var programSceneId: UUID?
    @Published var selectedLayerId: UUID?
    
    // Status
    @Published var isStreaming: Bool = false
    @Published var isRecording: Bool = false
    @Published var streamDuration: TimeInterval = 0
    @Published var recordingDuration: TimeInterval = 0
    
    // External Display
    @Published var isExternalScreenConnected: Bool = false
    @Published var externalScreenName: String = "None"
    
    // Toast notification
    @Published var toastMessage: String?
    
    private var streamTimer: AnyCancellable?
    private var recordTimer: AnyCancellable?
    private let storageKey = "LiveStreamer_Scenes_v2"
    
    init() {
        loadScenes()
    }
    
    // MARK: - Computed Properties
    
    var previewScene: LiveScene? {
        scenes.first(where: { $0.id == previewSceneId })
    }
    
    var programScene: LiveScene? {
        scenes.first(where: { $0.id == programSceneId })
    }
    
    var selectedLayer: SceneLayer? {
        guard let pScene = previewScene, let selId = selectedLayerId else { return nil }
        return pScene.layers.first(where: { $0.id == selId })
    }
    
    // MARK: - Scene Management
    
    func addScene(name: String? = nil) {
        let count = scenes.count + 1
        let sceneName = name ?? "Scene \(count)"
        
        // Setup initial default layers
        let defaultLayers: [SceneLayer] = [
            SceneLayer(
                name: "Camera 1",
                type: .camera,
                x: 0,
                y: 0,
                scale: 1.0,
                width: 640,
                height: 360
            ),
            SceneLayer(
                name: "Lower Third",
                type: .color,
                x: 0,
                y: 120,
                backgroundColor: CodableColor(red: 0.1, green: 0.1, blue: 0.15, opacity: 0.85),
                width: 500,
                height: 60,
                cornerRadius: 10
            ),
            SceneLayer(
                name: "Presenter Title",
                type: .text,
                x: 0,
                y: 120,
                text: "LIVE STREAM • HOST",
                textColor: .white,
                fontSize: 22,
                isBold: true
            )
        ]
        
        let newScene = LiveScene(name: sceneName, layers: defaultLayers)
        scenes.append(newScene)
        
        if previewSceneId == nil {
            previewSceneId = newScene.id
        }
        if programSceneId == nil {
            programSceneId = newScene.id
        }
        
        saveScenes()
    }
    
    func deleteScene(id: UUID) {
        scenes.removeAll { $0.id == id }
        if previewSceneId == id {
            previewSceneId = scenes.first?.id
        }
        if programSceneId == id {
            programSceneId = scenes.first?.id
        }
        saveScenes()
    }
    
    func duplicateScene(id: UUID) {
        guard let original = scenes.first(where: { $0.id == id }) else { return }
        var copy = original
        copy.id = UUID()
        copy.name = "\(original.name) (Copy)"
        copy.layers = original.layers.map {
            var layerCopy = $0
            layerCopy.id = UUID()
            return layerCopy
        }
        scenes.append(copy)
        previewSceneId = copy.id
        saveScenes()
    }
    
    func renameScene(id: UUID, newName: String) {
        guard let index = scenes.firstIndex(where: { $0.id == id }), !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        scenes[index].name = newName.trimmingCharacters(in: .whitespaces)
        saveScenes()
    }
    
    // MARK: - Layer Management
    
    func addLayer(to sceneId: UUID, type: LayerType) {
        guard let index = scenes.firstIndex(where: { $0.id == sceneId }) else { return }
        let layerNumber = scenes[index].layers.filter({ $0.type == type }).count + 1
        
        var newLayer: SceneLayer
        switch type {
        case .camera:
            newLayer = SceneLayer(name: "Camera \(layerNumber)", type: .camera, width: 480, height: 270)
        case .text:
            newLayer = SceneLayer(name: "Text \(layerNumber)", type: .text, text: "Sample Text", fontSize: 28)
        case .color:
            newLayer = SceneLayer(name: "Color Box \(layerNumber)", type: .color, backgroundColor: .blueColor, width: 240, height: 120, cornerRadius: 8)
        case .image:
            newLayer = SceneLayer(name: "Icon \(layerNumber)", type: .image, width: 80, height: 80, systemIconName: "star.fill")
        }
        
        scenes[index].layers.append(newLayer)
        selectedLayerId = newLayer.id
        saveScenes()
    }
    
    func deleteLayer(sceneId: UUID, layerId: UUID) {
        guard let index = scenes.firstIndex(where: { $0.id == sceneId }) else { return }
        scenes[index].layers.removeAll { $0.id == layerId }
        if selectedLayerId == layerId {
            selectedLayerId = nil
        }
        saveScenes()
    }
    
    func moveLayerUp(sceneId: UUID, layerId: UUID) {
        guard let sceneIndex = scenes.firstIndex(where: { $0.id == sceneId }),
              let layerIndex = scenes[sceneIndex].layers.firstIndex(where: { $0.id == layerId }),
              layerIndex < scenes[sceneIndex].layers.count - 1 else { return }
        scenes[sceneIndex].layers.swapAt(layerIndex, layerIndex + 1)
        saveScenes()
    }
    
    func moveLayerDown(sceneId: UUID, layerId: UUID) {
        guard let sceneIndex = scenes.firstIndex(where: { $0.id == sceneId }),
              let layerIndex = scenes[sceneIndex].layers.firstIndex(where: { $0.id == layerId }),
              layerIndex > 0 else { return }
        scenes[sceneIndex].layers.swapAt(layerIndex, layerIndex - 1)
        saveScenes()
    }
    
    func updateSelectedLayer(_ update: (inout SceneLayer) -> Void) {
        guard let pId = previewSceneId,
              let sIndex = scenes.firstIndex(where: { $0.id == pId }),
              let lId = selectedLayerId,
              let lIndex = scenes[sIndex].layers.firstIndex(where: { $0.id == lId }) else { return }
        update(&scenes[sIndex].layers[lIndex])
        saveScenes()
    }
    
    // MARK: - Studio Switcher Controls
    
    func cut() {
        withAnimation(.easeInOut(duration: 0.15)) {
            programSceneId = previewSceneId
        }
        showToast("CUT to \(previewScene?.name ?? "Scene")")
    }
    
    func autoTransition(duration: Double = 0.4) {
        withAnimation(.easeInOut(duration: duration)) {
            programSceneId = previewSceneId
        }
        showToast("TRANSITION to \(previewScene?.name ?? "Scene")")
    }
    
    func fadeToBlack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            programSceneId = nil
        }
        showToast("FADE TO BLACK")
    }
    
    // MARK: - Streaming & Recording
    
    func toggleStreaming() {
        isStreaming.toggle()
        if isStreaming {
            streamDuration = 0
            streamTimer = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.streamDuration += 1
                }
            showToast("🔴 STREAM STARTED")
        } else {
            streamTimer?.cancel()
            streamTimer = nil
            showToast("STREAM STOPPED")
        }
    }
    
    func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            recordingDuration = 0
            recordTimer = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.recordingDuration += 1
                }
            showToast("⚪️ RECORDING STARTED")
        } else {
            recordTimer?.cancel()
            recordTimer = nil
            showToast("RECORDING SAVED")
        }
    }
    
    func showToast(_ message: String) {
        self.toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveScenes() {
        do {
            let data = try JSONEncoder().encode(scenes)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save scenes: \(error)")
        }
    }
    
    private func loadScenes() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([LiveScene].self, from: data),
           !decoded.isEmpty {
            self.scenes = decoded
            self.previewSceneId = decoded.first?.id
            self.programSceneId = decoded.first?.id
        } else {
            // Setup initial default scenes
            setupDefaultScenes()
        }
    }
    
    private func setupDefaultScenes() {
        let scene1 = LiveScene(name: "Main Camera", layers: [
            SceneLayer(
                name: "Main Camera",
                type: .camera,
                x: 0,
                y: 0,
                scale: 1.0,
                width: 640,
                height: 360
            ),
            SceneLayer(
                name: "Lower Banner",
                type: .color,
                x: 0,
                y: 115,
                backgroundColor: CodableColor(red: 0.08, green: 0.12, blue: 0.22, opacity: 0.9),
                width: 440,
                height: 54,
                cornerRadius: 12
            ),
            SceneLayer(
                name: "Presenter Name",
                type: .text,
                x: 0,
                y: 115,
                text: "LIVE STREAMER",
                textColor: .white,
                fontSize: 18,
                isBold: true
            )
        ])
        
        let scene2 = LiveScene(name: "Starting Soon", layers: [
            SceneLayer(
                name: "Backdrop",
                type: .color,
                x: 0,
                y: 0,
                backgroundColor: CodableColor(red: 0.05, green: 0.05, blue: 0.1, opacity: 1.0),
                width: 640,
                height: 360,
                cornerRadius: 0
            ),
            SceneLayer(
                name: "Icon",
                type: .image,
                x: 0,
                y: -40,
                scale: 1.5,
                textColor: CodableColor(red: 0.3, green: 0.7, blue: 1.0, opacity: 1),
                systemIconName: "antenna.radiowaves.left.and.right"
            ),
            SceneLayer(
                name: "Title",
                type: .text,
                x: 0,
                y: 40,
                text: "STREAM STARTING SOON",
                textColor: .white,
                fontSize: 26,
                isBold: true
            )
        ])
        
        let scene3 = LiveScene(name: "Be Right Back", layers: [
            SceneLayer(
                name: "Backdrop",
                type: .color,
                x: 0,
                y: 0,
                backgroundColor: CodableColor(red: 0.08, green: 0.02, blue: 0.05, opacity: 1.0),
                width: 640,
                height: 360,
                cornerRadius: 0
            ),
            SceneLayer(
                name: "BRB Text",
                type: .text,
                x: 0,
                y: 0,
                text: "BE RIGHT BACK",
                textColor: CodableColor(red: 1.0, green: 0.3, blue: 0.4, opacity: 1.0),
                fontSize: 32,
                isBold: true
            )
        ])
        
        self.scenes = [scene1, scene2, scene3]
        self.previewSceneId = scene1.id
        self.programSceneId = scene1.id
        saveScenes()
    }
}

// MARK: - Scene Canvas View (High Performance Declarative Renderer)

struct SceneCanvasView: View {
    let scene: LiveScene?
    var isInteractive: Bool = false
    var selectedLayerId: UUID? = nil
    var onSelectLayer: ((UUID) -> Void)? = nil
    var onDragLayer: ((UUID, CGSize) -> Void)? = nil
    
    var body: some View {
        GeometryReader { geometry in
            let frameWidth = geometry.size.width
            let frameHeight = geometry.size.height
            // Standard virtual canvas size: 640x360 (16:9)
            let scaleRatio = min(frameWidth / 640.0, frameHeight / 360.0)
            
            ZStack {
                // Black base canvas
                Color.black
                    .frame(width: frameWidth, height: frameHeight)
                
                if let layers = scene?.layers {
                    ForEach(layers) { layer in
                        if layer.isVisible {
                            LayerRenderView(layer: layer)
                                .scaleEffect(layer.scale)
                                .rotationEffect(.degrees(layer.rotation))
                                .opacity(layer.opacity)
                                .offset(x: layer.x * scaleRatio, y: layer.y * scaleRatio)
                                .overlay(
                                    // Selection highlight in interactive preview mode
                                    Group {
                                        if isInteractive && selectedLayerId == layer.id {
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(Color.green, lineWidth: 2)
                                                .padding(-4)
                                        }
                                    }
                                )
                                .onTapGesture {
                                    if isInteractive {
                                        onSelectLayer?(layer.id)
                                    }
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            guard isInteractive && !layer.isLocked else { return }
                                            let delta = CGSize(
                                                width: value.translation.width / scaleRatio,
                                                height: value.translation.height / scaleRatio
                                            )
                                            onDragLayer?(layer.id, delta)
                                        }
                                )
                        }
                    }
                } else {
                    // Blank / Black out state
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("BLACK OUT")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(width: frameWidth, height: frameHeight)
            .clipped()
        }
        .aspectRatio(16/9, contentMode: .fit)
    }
}

// MARK: - Layer Render View

struct LayerRenderView: View {
    let layer: SceneLayer
    
    var body: some View {
        switch layer.type {
        case .camera:
            CameraPreviewView()
                .frame(width: layer.width, height: layer.height)
                .cornerRadius(layer.cornerRadius)
                .clipped()
                
        case .text:
            Text(layer.text)
                .font(.system(size: layer.fontSize, weight: layer.isBold ? .bold : .regular, design: .rounded))
                .foregroundColor(layer.textColor.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                
        case .color:
            RoundedRectangle(cornerRadius: layer.cornerRadius)
                .fill(layer.backgroundColor.color)
                .frame(width: layer.width, height: layer.height)
                
        case .image:
            Image(systemName: layer.systemIconName)
                .resizable()
                .scaledToFit()
                .foregroundColor(layer.textColor.color)
                .frame(width: layer.width > 0 ? layer.width : 60, height: layer.height > 0 ? layer.height : 60)
        }
    }
}

// MARK: - Layer Inspector View

struct LayerInspectorView: View {
    @ObservedObject var streamManager = StreamManager.shared
    
    var body: some View {
        if let layer = streamManager.selectedLayer {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    Image(systemName: layer.type.iconName)
                        .foregroundColor(.blue)
                    Text(layer.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        streamManager.selectedLayerId = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 4)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Type Specific Controls
                        switch layer.type {
                        case .text:
                            textControls(layer: layer)
                        case .camera:
                            cameraControls(layer: layer)
                        case .color:
                            colorControls(layer: layer)
                        case .image:
                            imageControls(layer: layer)
                        }
                        
                        Divider().background(Color.white.opacity(0.15))
                        
                        // Transform Controls
                        transformControls(layer: layer)
                    }
                }
            }
            .padding(12)
            .background(Color(white: 0.12))
            .cornerRadius(12)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
                Text("Select a layer in Preview or Sources to inspect & edit")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(12)
            .background(Color(white: 0.08))
            .cornerRadius(12)
        }
    }
    
    // MARK: Inspector Subviews
    
    @ViewBuilder
    private func textControls(layer: SceneLayer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TEXT CONTENT")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            TextField("Content", text: Binding(
                get: { layer.text },
                set: { newText in
                    streamManager.updateSelectedLayer { $0.text = newText }
                }
            ))
            .textFieldStyle(.roundedBorder)
            
            HStack {
                Text("Font Size: \(Int(layer.fontSize))")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Slider(value: Binding(
                    get: { layer.fontSize },
                    set: { newSize in streamManager.updateSelectedLayer { $0.fontSize = newSize } }
                ), in: 12...72, step: 1)
                .frame(width: 140)
            }
            
            ColorPicker("Color", selection: Binding(
                get: { layer.textColor.color },
                set: { newColor in streamManager.updateSelectedLayer { $0.textColor = CodableColor(newColor) } }
            ))
            .font(.caption)
            .foregroundColor(.white)
        }
    }
    
    @ViewBuilder
    private func cameraControls(layer: SceneLayer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CAMERA SOURCE")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            HStack {
                Button(action: {
                    CameraService.shared.switchCamera(to: .back)
                }) {
                    Label("Back Camera", systemImage: "camera")
                        .font(.caption)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(CameraService.shared.currentPosition == .back ? Color.blue : Color(white: 0.2))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                
                Button(action: {
                    CameraService.shared.switchCamera(to: .front)
                }) {
                    Label("Front (Selfie)", systemImage: "camera.rotate")
                        .font(.caption)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(CameraService.shared.currentPosition == .front ? Color.blue : Color(white: 0.2))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }
            
            HStack {
                Text("Corner Radius: \(Int(layer.cornerRadius))")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Slider(value: Binding(
                    get: { layer.cornerRadius },
                    set: { newRadius in streamManager.updateSelectedLayer { $0.cornerRadius = newRadius } }
                ), in: 0...50, step: 1)
                .frame(width: 130)
            }
        }
    }
    
    @ViewBuilder
    private func colorControls(layer: SceneLayer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SHAPE & COLOR")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            ColorPicker("Fill Color", selection: Binding(
                get: { layer.backgroundColor.color },
                set: { newColor in streamManager.updateSelectedLayer { $0.backgroundColor = CodableColor(newColor) } }
            ))
            .font(.caption)
            .foregroundColor(.white)
            
            HStack {
                Text("Width: \(Int(layer.width))")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Slider(value: Binding(
                    get: { layer.width },
                    set: { newW in streamManager.updateSelectedLayer { $0.width = newW } }
                ), in: 20...640, step: 5)
                .frame(width: 140)
            }
            
            HStack {
                Text("Height: \(Int(layer.height))")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Slider(value: Binding(
                    get: { layer.height },
                    set: { newH in streamManager.updateSelectedLayer { $0.height = newH } }
                ), in: 10...360, step: 5)
                .frame(width: 140)
            }
            
            HStack {
                Text("Corner Radius: \(Int(layer.cornerRadius))")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Slider(value: Binding(
                    get: { layer.cornerRadius },
                    set: { newR in streamManager.updateSelectedLayer { $0.cornerRadius = newR } }
                ), in: 0...50, step: 1)
                .frame(width: 140)
            }
        }
    }
    
    @ViewBuilder
    private func imageControls(layer: SceneLayer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ICON")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            HStack(spacing: 8) {
                ForEach(["star.fill", "antenna.radiowaves.left.and.right", "sparkles", "bolt.fill", "heart.fill"], id: \.self) { icon in
                    Button(action: {
                        streamManager.updateSelectedLayer { $0.systemIconName = icon }
                    }) {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: 36, height: 36)
                            .background(layer.systemIconName == icon ? Color.blue : Color(white: 0.2))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func transformControls(layer: SceneLayer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRANSFORM")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            
            HStack {
                Text("X: \(Int(layer.x))")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Slider(value: Binding(
                    get: { layer.x },
                    set: { newX in streamManager.updateSelectedLayer { $0.x = newX } }
                ), in: -320...320, step: 1)
                .frame(width: 150)
            }
            
            HStack {
                Text("Y: \(Int(layer.y))")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Slider(value: Binding(
                    get: { layer.y },
                    set: { newY in streamManager.updateSelectedLayer { $0.y = newY } }
                ), in: -180...180, step: 1)
                .frame(width: 150)
            }
            
            HStack {
                Text("Scale: \(String(format: "%.2f", layer.scale))x")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Slider(value: Binding(
                    get: { layer.scale },
                    set: { newS in streamManager.updateSelectedLayer { $0.scale = newS } }
                ), in: 0.2...3.0, step: 0.05)
                .frame(width: 150)
            }
            
            HStack {
                Text("Rotate: \(Int(layer.rotation))°")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Slider(value: Binding(
                    get: { layer.rotation },
                    set: { newR in streamManager.updateSelectedLayer { $0.rotation = newR } }
                ), in: -180...180, step: 1)
                .frame(width: 150)
            }
            
            HStack {
                Text("Opacity: \(Int(layer.opacity * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Slider(value: Binding(
                    get: { layer.opacity },
                    set: { newO in streamManager.updateSelectedLayer { $0.opacity = newO } }
                ), in: 0.0...1.0, step: 0.05)
                .frame(width: 150)
            }
            
            // Center button
            Button(action: {
                streamManager.updateSelectedLayer {
                    $0.x = 0
                    $0.y = 0
                    $0.rotation = 0
                    $0.scale = 1.0
                }
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "scope")
                    Text("Center Layer")
                    Spacer()
                }
                .font(.caption)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .foregroundColor(.white)
                .cornerRadius(6)
            }
        }
    }
}

// MARK: - Legacy compatibility stub
// If any other file references SenceView, alias to SceneCanvasView

struct SenceView: View {
    @Binding var theme: String
    @Binding var input: [String]
    
    var body: some View {
        SceneCanvasView(scene: StreamManager.shared.previewScene)
    }
}
