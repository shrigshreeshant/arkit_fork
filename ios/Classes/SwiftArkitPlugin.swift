import ARKit
import Flutter
import UIKit

public class SwiftArkitPlugin: NSObject, FlutterPlugin {

    public static var registrar: FlutterPluginRegistrar? = nil

    public static func register(with registrar: FlutterPluginRegistrar) {

        print("ARKit Plugin: Starting registration")

        print("ARKit Plugin: Setting up camera stream channel")

        print("ARKit Plugin: Setting up ARKit factory")
        SwiftArkitPlugin.registrar = registrar
        let arkitFactory = FlutterArkitFactory(messenger: registrar.messenger())

        registrar.register(arkitFactory, withId: "arkit")

        print("ARKit Plugin: Setting up configuration channel")
        let channel = FlutterMethodChannel(
            name: "arkit_configuration", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(SwiftArkitPlugin(), channel: channel)

        print("ARKit Plugin: Registration completed")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("ARKit Plugin: Handling method call: \(call.method)")

        switch call.method {
        case "checkConfiguration":
            let res = checkConfiguration(call.arguments)
            result(res)

        case "checkLidarAvailability":
            result(isLidarSupported())

        default:
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

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
        -> FlutterPlatformView
    {
        print("ARKit Factory: Creating view with ID: \(viewId)")
        let view = FlutterArkitView(frame:frame, viewIdentifier: viewId,arguments:args, binaryMessenger: messenger)
        print("ARKit Factory: View created successfully")
        return view
    }

}

class CameraStreamHandler: NSObject, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private weak var arRecordingManager: ARCameraRecordingManager?

    var lastFrameTime = Date()
    let minFrameInterval: TimeInterval = 1.0 / 15.0

    init(arRecordingManager: ARCameraRecordingManager) {
        self.arRecordingManager = arRecordingManager
        super.init()
        print("CameraStreamHandler: initialized")

    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
        -> FlutterError?
    {
        print("CameraStreamHandler: Starting to listen")
        eventSink = events
        arRecordingManager?.rgbStreamer.setEventSink(eventSink)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        arRecordingManager=nil

        eventSink = nil
        return nil
    }
    
    deinit{
        print("CameraStreamHandler: deinitialized")

        arRecordingManager=nil
        eventSink = nil
        
    }

}
