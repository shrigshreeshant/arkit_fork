//
//  MetalRecorder.swift
//  Pods
//
//  Created by shreeshant prajapati on 10/07/2025.
//

import UIKit
import SceneKit
import Metal
import MetalKit
import AVFoundation

// MARK: - Metal Scene Recorder
class MetalSceneRecorder {
    
    // MARK: - Properties
    private var metalDevice: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var renderer: SCNRenderer!
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var textureCache: CVMetalTextureCache?
    private var frameCount: Int64 = 0
    private var isRecording = false
    private var recordingTimer: Timer?
    private var outputURL: URL?
    
    // Recording settings
    private let targetFPS: Double = 24
    private let bitRate: Int = 5000000 // 5 Mbps
    
    // MARK: - Initialization
    init() {
        setupMetal()
    }
    
    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        metalDevice = device
        commandQueue = device.makeCommandQueue()
        renderer = SCNRenderer(device: device, options: nil)
        
        // Create texture cache for efficient conversions
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
    }
    
    // MARK: - Public Methods
    func startRecording(scene: SCNScene, size: CGSize, pointOfView: SCNNode? = nil) {
        guard !isRecording else {
            print("Already recording")
            return
        }
        
        // Set up the renderer
        renderer.scene = scene
        if let pov = pointOfView {
            renderer.pointOfView = pov
        }
        
        // Create output URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "scene_recording_\(Date().timeIntervalSince1970).mp4"
        outputURL = documentsPath.appendingPathComponent(fileName)
        
        // Remove existing file if it exists
        if let url = outputURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        // Set up video writer
        guard setupVideoWriter(size: size) else {
            print("Failed to setup video writer")
            return
        }
        
        isRecording = true
        frameCount = 0
        
        // Start recording timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0/targetFPS, repeats: true) { [weak self] _ in
            self?.captureFrame(size: size)
        }
        
        print("Recording started")
    }
    
    func stopRecording(completion: @escaping (URL?, Error?) -> Void) {
        guard isRecording else {
            completion(nil, NSError(domain: "RecorderError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not currently recording"]))
            return
        }
        
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Finish writing
        videoInput?.markAsFinished()
        assetWriter?.finishWriting { [weak self] in
            DispatchQueue.main.async {
                if let error = self?.assetWriter?.error {
                    completion(nil, error)
                } else {
                    completion(self?.outputURL, nil)
                }
            }
        }
        
        print("Recording stopped")
    }
    
    var recording: Bool {
        return isRecording
    }
    
    // MARK: - Private Methods
    private func setupVideoWriter(size: CGSize) -> Bool {
        guard let outputURL = outputURL else { return false }
        
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: bitRate,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
                ]
            ]
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput!,
                sourcePixelBufferAttributes: pixelBufferAttributes
            )
            
            guard let videoInput = videoInput else { return false }
            assetWriter?.add(videoInput)
            
            return assetWriter?.startWriting() == true && {
                assetWriter?.startSession(atSourceTime: .zero)
                return true
            }()
            
        } catch {
            print("Failed to setup video writer: \(error)")
            return false
        }
    }
    
    private func captureFrame(size: CGSize) {
        guard let pixelBufferAdaptor = pixelBufferAdaptor,
              let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else { return }
        
        // Render the scene to a Metal texture
        guard let pixelBuffer = renderSceneToPixelBuffer(size: size) else { return }
        
        let frameTime = CMTime(value: frameCount, timescale: Int32(targetFPS))
        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: frameTime)
        frameCount += 1
    }
    
    private func renderSceneToPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)
        
        // Create texture descriptor
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        
        guard let texture = metalDevice.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        // Create render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        // Render the scene
        let viewport = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create command buffer")
            return nil
        }
        
        renderer.render(
            atTime: CFTimeInterval(frameCount) / targetFPS,
            viewport: viewport,
            commandBuffer: commandBuffer,
            passDescriptor: renderPassDescriptor
        )
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Convert Metal texture to CVPixelBuffer
        return metalTextureToPixelBuffer(texture: texture)
    }
    
    private func metalTextureToPixelBuffer(texture: MTLTexture) -> CVPixelBuffer? {
        let width = texture.width
        let height = texture.height
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ] as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        guard let textureCache = textureCache else { return nil }
        
        var metalTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            buffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &metalTexture
        )
        
        guard let destTexture = CVMetalTextureGetTexture(metalTexture!) else {
            return nil
        }
        
        // Copy texture data using Metal blit encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            return nil
        }
        
        blitEncoder.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: destTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return buffer
    }
}

// MARK: - Video Export Helper
extension MetalSceneRecorder {
    
    func exportVideo(url: URL, completion: @escaping (Bool, Error?) -> Void) {
        // Video is already saved to Documents directory
        // You can copy it elsewhere or process it further
        completion(true, nil)
    }
    
    func getVideoData(url: URL) -> Data? {
        return try? Data(contentsOf: url)
    }
}

// MARK: - Example Usage View Controller
class SceneRecorderViewController: UIViewController {
    
    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    
    private var recorder = MetalSceneRecorder()
    private var scene: SCNScene!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        setupUI()
    }
    
    private func setupScene() {
        // Create a simple scene with a rotating cube
        scene = SCNScene()
        
        // Add a cube
        let cubeGeometry = SCNBox(width: 2, height: 2, length: 2, chamferRadius: 0.1)
        let cubeNode = SCNNode(geometry: cubeGeometry)
        cubeNode.position = SCNVector3(0, 0, 0)
        
        // Add material
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemBlue
        material.metalness.contents = 0.8
        material.roughness.contents = 0.2
        cubeGeometry.materials = [material]
        
        scene.rootNode.addChildNode(cubeNode)
        
        // Add rotation animation
        let rotation = CABasicAnimation(keyPath: "rotation")
        rotation.fromValue = SCNVector4(0, 1, 0, 0)
        rotation.toValue = SCNVector4(0, 1, 0, Float.pi * 2)
        rotation.duration = 3
        rotation.repeatCount = .infinity
        cubeNode.addAnimation(rotation, forKey: "rotation")
        
        // Add lighting
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.intensity = 1000
        lightNode.position = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(lightNode)
        
        // Add ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 200
        scene.rootNode.addChildNode(ambientLight)
        
        // Set up camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 8)
        scene.rootNode.addChildNode(cameraNode)
        
        // Assign scene to view
        sceneView.scene = scene
        sceneView.backgroundColor = UIColor.black
        sceneView.allowsCameraControl = true
    }
    
    private func setupUI() {
        recordButton.layer.cornerRadius = 8
        updateUI()
    }
    
    private func updateUI() {
        if recorder.recording {
            recordButton.setTitle("Stop Recording", for: .normal)
            recordButton.backgroundColor = .systemRed
            statusLabel.text = "Recording..."
        } else {
            recordButton.setTitle("Start Recording", for: .normal)
            recordButton.backgroundColor = .systemBlue
            statusLabel.text = "Ready to record"
        }
    }
    
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        if recorder.recording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        let size = CGSize(width: 1280, height: 720) // HD resolution
        recorder.startRecording(scene: scene, size: size, pointOfView: sceneView.pointOfView)
        updateUI()
    }
    
    private func stopRecording() {
        recorder.stopRecording { [weak self] url, error in
            self?.updateUI()
            
            if let error = error {
                self?.showAlert(title: "Recording Error", message: error.localizedDescription)
            } else if let url = url {
                self?.handleRecordingComplete(url: url)
            }
        }
    }
    
    private func handleRecordingComplete(url: URL) {
        let alert = UIAlertController(title: "Recording Complete", message: "What would you like to do with your video?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Share", style: .default) { _ in
            self.shareVideo(url: url)
        })
        
        alert.addAction(UIAlertAction(title: "Export to Files", style: .default) { _ in
            self.exportToFiles(url: url)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func exportToFiles(url: URL) {
        let documentPicker = UIDocumentPickerViewController(forExporting: [url])
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        present(documentPicker, animated: true)
    }
    
    private func shareVideo(url: URL) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // For iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = recordButton
            popover.sourceRect = recordButton.bounds
        }
        
        present(activityViewController, animated: true)
    }
}

// MARK: - Document Picker Delegate
extension SceneRecorderViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        statusLabel.text = "Video exported successfully!"
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        statusLabel.text = "Export cancelled"
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Additional Extensions
extension UIViewController {
    func showSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
