import ARKit
import Flutter
import UIKit

public class SwiftArkitPlugin: NSObject, FlutterPlugin {
    public static var registrar: FlutterPluginRegistrar? = nil

    public static func register(with registrar: FlutterPluginRegistrar) {
        print("ARKit Plugin: Starting registration")
        
        print("ARKit Plugin: Setting up camera stream channel")
        let cameraStreamChannel = FlutterEventChannel(name: "arkit/cameraStream", binaryMessenger: registrar.messenger())
        let cameraStreamHandler: CameraStreamHandler = CameraStreamHandler.shared
        cameraStreamChannel.setStreamHandler(cameraStreamHandler)
        
        print("ARKit Plugin: Setting up ARKit factory")
        SwiftArkitPlugin.registrar = registrar
        let arkitFactory = FlutterArkitFactory(messenger: registrar.messenger())
        registrar.register(arkitFactory, withId: "arkit")

        print("ARKit Plugin: Setting up configuration channel")
        let channel = FlutterMethodChannel(name: "arkit_configuration", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(SwiftArkitPlugin(), channel: channel)
        
        print("ARKit Plugin: Registration completed")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("ARKit Plugin: Handling method call: \(call.method)")
        if call.method == "checkConfiguration" {
            print("ARKit Plugin: Checking configuration")
            let res = checkConfiguration(call.arguments)
            print("ARKit Plugin: Configuration check result: \(res)")
            result(res)
        } else {
            print("ARKit Plugin: Method not implemented: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
}

class FlutterArkitFactory: NSObject, FlutterPlatformViewFactory {
    let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        print("ARKit Factory: Initializing")
        self.messenger = messenger
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments _: Any?) -> FlutterPlatformView {
        print("ARKit Factory: Creating view with ID: \(viewId)")
        let view = FlutterArkitView(withFrame: frame, viewIdentifier: viewId, messenger: messenger)
        print("ARKit Factory: View created successfully")
        return view
    }
}

class CameraStreamHandler: NSObject, FlutterStreamHandler {
    static let shared: CameraStreamHandler = CameraStreamHandler()
    private var eventSink: FlutterEventSink?
    private var displayLink: CADisplayLink?
    private var activeSceneView: ARSCNView?
    
    private override init() {
        super.init()
        print("CameraStreamHandler: Initializing")
    }
    
    func setActiveSceneView(_ sceneView: ARSCNView) {
        print("CameraStreamHandler: Setting active scene view")
        activeSceneView = sceneView
        if eventSink != nil && displayLink == nil {
            print("Camera Stream Handler: Starting camera streaming")
            startCameraStreaming()
        }
    }
    
    func clearActiveSceneView() {
        print("CameraStreamHandler: Clearing active scene view")
        activeSceneView = nil
        stopCameraStreaming()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("CameraStreamHandler: Starting to listen")
        eventSink = events
        if activeSceneView != nil {
            startCameraStreaming()
        }
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("CameraStreamHandler: Cancelling stream")
        stopCameraStreaming()
        eventSink = nil
        return nil
    }
    
    func startCameraStreaming() {
        print("CameraStreamHandler: Starting camera streaming")
        guard displayLink == nil, activeSceneView != nil else { 
            print("CameraStreamHandler: Cannot start streaming - displayLink or activeSceneView is nil")
            return 
        }
        displayLink = CADisplayLink(target: self, selector: #selector(streamCameraFrame))
        displayLink?.preferredFramesPerSecond = 30
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopCameraStreaming() {
        print("CameraStreamHandler: Stopping camera streaming")
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc func streamCameraFrame() {
        guard let sceneView = activeSceneView,
              let frame = sceneView.session.currentFrame,
              let eventSink = eventSink else { 
            print("CameraStreamHandler: Cannot stream frame - missing required components")
            return 
        }
        
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Rotate the image by 90 degrees
            let rotatedImage = ciImage.transformed(by: CGAffineTransform(rotationAngle: .pi/2))
            
            guard let cgImage = context.createCGImage(rotatedImage, from: rotatedImage.extent) else { 
                print("CameraStreamHandler: Failed to create CGImage")
                return 
            }
            
            let image = UIImage(cgImage: cgImage)
            guard let jpegData = image.jpegData(compressionQuality: 0.5) else { 
                print("CameraStreamHandler: Failed to create JPEG data")
                return 
            }
            
            let flutterData = FlutterStandardTypedData(bytes: jpegData)
            DispatchQueue.main.async {
                eventSink(flutterData)
            }
        }
    }
}