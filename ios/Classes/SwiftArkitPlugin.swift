import ARKit
import Flutter
import UIKit
import os.log

public class SwiftArkitPlugin: NSObject, FlutterPlugin {
    public static var registrar: FlutterPluginRegistrar? = nil
    private let logger = Logger(subsystem: "com.example.arkit", category: "SwiftArkitPlugin")

    public static func register(with registrar: FlutterPluginRegistrar) {
        logger.log("ARKit Plugin: Starting registration")
        
        logger.log("ARKit Plugin: Setting up camera stream channel")
        let cameraStreamChannel = FlutterEventChannel(name: "arkit/cameraStream", binaryMessenger: registrar.messenger())
        let cameraStreamHandler: CameraStreamHandler = CameraStreamHandler.shared
        cameraStreamChannel.setStreamHandler(cameraStreamHandler)
        
        logger.log("ARKit Plugin: Setting up ARKit factory")
        SwiftArkitPlugin.registrar = registrar
        let arkitFactory = FlutterArkitFactory(messenger: registrar.messenger())
        registrar.register(arkitFactory, withId: "arkit")

        logger.log("ARKit Plugin: Setting up configuration channel")
        let channel = FlutterMethodChannel(name: "arkit_configuration", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(SwiftArkitPlugin(), channel: channel)
        
        logger.log("ARKit Plugin: Registration completed")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        logger.log("ARKit Plugin: Handling method call: \(call.method)")
        if call.method == "checkConfiguration" {
            logger.log("ARKit Plugin: Checking configuration")
            let res = checkConfiguration(call.arguments)
            logger.log("ARKit Plugin: Configuration check result: \(res)")
            result(res)
        } else {
            logger.log("ARKit Plugin: Method not implemented: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
}

class FlutterArkitFactory: NSObject, FlutterPlatformViewFactory {
    let messenger: FlutterBinaryMessenger
    private let logger = Logger(subsystem: "com.example.arkit", category: "FlutterArkitFactory")

    init(messenger: FlutterBinaryMessenger) {
        logger.log("ARKit Factory: Initializing")
        self.messenger = messenger
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments _: Any?) -> FlutterPlatformView {
        logger.log("ARKit Factory: Creating view with ID: \(viewId)")
        let view = FlutterArkitView(withFrame: frame, viewIdentifier: viewId, messenger: messenger)
        logger.log("ARKit Factory: View created successfully")
        return view
    }
}

class CameraStreamHandler: NSObject, FlutterStreamHandler {
    static let shared: CameraStreamHandler = CameraStreamHandler()
    private var eventSink: FlutterEventSink?
    private var displayLink: CADisplayLink?
    private var activeSceneView: ARSCNView?
    private let logger = Logger(subsystem: "com.example.arkit", category: "CameraStreamHandler")
    
    private override init() {
        super.init()
        logger.log("CameraStreamHandler: Initializing")
    }
    
    func setActiveSceneView(_ sceneView: ARSCNView) {
        logger.log("CameraStreamHandler: Setting active scene view")
        activeSceneView = sceneView
        if eventSink != nil && displayLink == nil {
            logger.log("Camera Stream Handler: Starting camera streaming")
            startCameraStreaming()
        }
    }
    
    func clearActiveSceneView() {
        logger.log("CameraStreamHandler: Clearing active scene view")
        activeSceneView = nil
        stopCameraStreaming()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        logger.log("CameraStreamHandler: Starting to listen")
        eventSink = events
        if activeSceneView != nil {
            startCameraStreaming()
        }
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        logger.log("CameraStreamHandler: Cancelling stream")
        stopCameraStreaming()
        eventSink = nil
        return nil
    }
    
    func startCameraStreaming() {
        logger.log("CameraStreamHandler: Starting camera streaming")
        guard displayLink == nil, activeSceneView != nil else { 
            logger.log("CameraStreamHandler: Cannot start streaming - displayLink or activeSceneView is nil")
            return 
        }
        displayLink = CADisplayLink(target: self, selector: #selector(streamCameraFrame))
        displayLink?.preferredFramesPerSecond = 30
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopCameraStreaming() {
        logger.log("CameraStreamHandler: Stopping camera streaming")
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc func streamCameraFrame() {
        guard let sceneView = activeSceneView,
              let frame = sceneView.session.currentFrame,
              let eventSink = eventSink else { 
            logger.log("CameraStreamHandler: Cannot stream frame - missing required components")
            return 
        }
        
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { 
                self.logger.log("CameraStreamHandler: Failed to create CGImage")
                return 
            }
            
            let image = UIImage(cgImage: cgImage)
            guard let jpegData = image.jpegData(compressionQuality: 0.5) else { 
                self.logger.log("CameraStreamHandler: Failed to create JPEG data")
                return 
            }
            
            let flutterData = FlutterStandardTypedData(bytes: jpegData)
            DispatchQueue.main.async {
                eventSink(flutterData)
            }
        }
    }
}