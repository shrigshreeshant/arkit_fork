import ARKit
import Flutter
import UIKit

public class SwiftArkitPlugin: NSObject, FlutterPlugin {
    public static var registrar: FlutterPluginRegistrar? = nil

    public static func register(with registrar: FlutterPluginRegistrar) {

        let cameraStreamChannel = FlutterEventChannel(name: "arkit/cameraStream", binaryMessenger: registrar.messenger())
        let cameraStreamHandler: CameraStreamHandler = CameraStreamHandler.shared
        cameraStreamChannel.setStreamHandler(cameraStreamHandler)
        
        SwiftArkitPlugin.registrar = registrar
        let arkitFactory = FlutterArkitFactory(messenger: registrar.messenger())
        registrar.register(arkitFactory, withId: "arkit")

        let channel = FlutterMethodChannel(name: "arkit_configuration", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(SwiftArkitPlugin(), channel: channel)


    
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "checkConfiguration" {
            let res = checkConfiguration(call.arguments)
            result(res)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
}

class FlutterArkitFactory: NSObject, FlutterPlatformViewFactory {
    let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments _: Any?) -> FlutterPlatformView {
        let view = FlutterArkitView(withFrame: frame, viewIdentifier: viewId, messenger: messenger)
        
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
    }
    
    func setActiveSceneView(_ sceneView: ARSCNView) {
        activeSceneView = sceneView
        if eventSink != nil && displayLink == nil {
            startCameraStreaming()
        }
    }
    
    func clearActiveSceneView() {
        activeSceneView = nil
        stopCameraStreaming()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        if activeSceneView != nil {
            startCameraStreaming()
        }
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopCameraStreaming()
        eventSink = nil
        return nil
    }
    
    func startCameraStreaming() {
        guard displayLink == nil, activeSceneView != nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(streamCameraFrame))
        displayLink?.preferredFramesPerSecond = 30
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopCameraStreaming() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc func streamCameraFrame() {
        guard let sceneView = activeSceneView,
              let frame = sceneView.session.currentFrame,
              let eventSink = eventSink else { return }
        
        let pixelBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            let image = UIImage(cgImage: cgImage)
            guard let jpegData = image.jpegData(compressionQuality: 0.5) else { return }
            
            let flutterData = FlutterStandardTypedData(bytes: jpegData)
            DispatchQueue.main.async {
                eventSink(flutterData)
            }
        }
    }
}