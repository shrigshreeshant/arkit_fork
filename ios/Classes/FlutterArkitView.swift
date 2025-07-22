import ARKit
import Flutter
import Foundation
import SCNRecorder


class FlutterArkitView: NSObject, FlutterPlatformView, RenderARDelegate, RecordARDelegate {
    func frame(didRender buffer: CVPixelBuffer, with time: CMTime, using rawBuffer: CVPixelBuffer) {
    
    }
    
    func recorder(didEndRecording path: URL, with noError: Bool) {
    
    }
    
    func recorder(didFailRecording error: (any Error)?, and status: String) {
    
    }
    
    func recorder(willEnterBackground status: RecordARStatus) {
    
    }
    
    let sceneView: ARSCNView
    let channel: FlutterMethodChannel
    var cameraStreamEventSink: FlutterEventSink?
    var displayLink: CADisplayLink?
    var recordingManager : ARCameraRecordingManager?
    
    var recorder: RecordAR?
    var forceTapOnCenter: Bool = false
    var configuration: ARConfiguration? = nil
    let recordingQueue = DispatchQueue(label: "recordingThread", attributes: .concurrent)
    let arRecordingQueue = DispatchQueue(label: "arRecordingThread", attributes: .concurrent)


    init(
        withFrame frame: CGRect, viewIdentifier viewId: Int64, messenger msg: FlutterBinaryMessenger
    ) {
        sceneView = ARSCNView(frame: frame)
        recordingManager = ARCameraRecordingManager(session: sceneView.session)
       
        channel = FlutterMethodChannel(name: "arkit_\(viewId)", binaryMessenger: msg)

        super.init()
        recorder = RecordAR(ARSceneKit: sceneView)
        
               /*----👇---- ARVideoKit Configuration ----👇----*/
               
               // Set the recorder's delegate
               recorder?.delegate = self

               // Set the renderer's delegate
               recorder?.renderAR = self
               
               // Configure the renderer to perform additional image & video processing 👁
               recorder?.onlyRenderWhileRecording = false
        
        recorder?.enableAudio=true
               
               // Configure ARKit content mode. Default is .auto
               recorder?.contentMode = .aspectFill
               
               //record or photo add environment light rendering, Default is false
               recorder?.enableAdjustEnvironmentLighting = true
               
               // Set the UIViewController orientations
               recorder?.inputViewOrientations = [.landscapeLeft, .landscapeRight, .portrait]
               // Configure RecordAR to store media files in local app directory
               recorder?.deleteCacheWhenExported = false

        sceneView.delegate = self
        channel.setMethodCallHandler(onMethodCalled)

        print("FlutterArkitView: Initializing AR configuration")
        let config = ARWorldTrackingConfiguration()
        config.isLightEstimationEnabled = false
        config.environmentTexturing = .none
        config.frameSemantics = [] // Don'
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
            print("✅ sceneDepth supported and enabled")
        } else {
            print("❌ sceneDepth not supported on this device")
        }

        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        print("✅ ARSession started with depth config")

        setupEventChannels(messenger: msg)
    }

    func view() -> UIView { return sceneView }
    func setupEventChannels(messenger: FlutterBinaryMessenger) {
        print("FlutterArkitView: Setting up event channels")
        CameraStreamHandler.shared.setActiveSceneView(sceneView)
        print("FlutterArkitView: Event channels set up")
    }

    func onMethodCalled(_ call: FlutterMethodCall, _ result:@escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any]

        if configuration == nil && call.method != "init" {
            logPluginError("plugin is not initialized properly", toChannel: channel)
            result(nil)
            return
        }

        switch call.method {
        case "init":
            initalize(arguments!, result)
            result(nil)
        case "addARKitNode":
            onAddNode(arguments!)
            result(nil)
        case "onUpdateNode":
            onUpdateNodes(arguments!)
            result(nil)
        case "groupNode":
            onUpdateNodes(arguments!)
            result(nil)

        case "removeARKitNode":
            onRemoveNode(arguments!)
            result(nil)
        case "removeARKitAnchor":
            onRemoveAnchor(arguments!)
      
            result(nil)
        case "addCoachingOverlay":
            if #available(iOS 13.0, *) {
                addCoachingOverlay(arguments!)
            }
            result(nil)
        case "removeCoachingOverlay":
            if #available(iOS 13.0, *) {
                removeCoachingOverlay()
            }
            result(nil)
        case "getNodeBoundingBox":
            onGetNodeBoundingBox(arguments!, result)
        case "transformationChanged":
            onTransformChanged(arguments!)
            result(nil)
        case "isHiddenChanged":
            onIsHiddenChanged(arguments!)
            result(nil)
        case "updateSingleProperty":
            onUpdateSingleProperty(arguments!)
            result(nil)
        case "updateMaterials":
            onUpdateMaterials(arguments!)
            result(nil)
        case "performHitTest":
            onPerformHitTest(arguments!, result)
        case "performARRaycastHitTest":
            onPerformARRaycastHitTest(arguments!, result)
        case "updateFaceGeometry":
            onUpdateFaceGeometry(arguments!)
            result(nil)
        case "getLightEstimate":
            onGetLightEstimate(result)
            result(nil)
        case "projectPoint":
            onProjectPoint(arguments!, result)
        case "cameraProjectionMatrix":
            onCameraProjectionMatrix(result)
        case "cameraTransform":
            onCameraTransform(result)
        case "cameraViewMatrix":
            onCameraViewMatrix(result)
        case "pointOfViewTransform":
            onPointOfViewTransform(result)
        case "playAnimation":
            onPlayAnimation(arguments!)
            result(nil)
        case "stopAnimation":
            onStopAnimation(arguments!)
            result(nil)
        case "dispose":
            onDispose(result)
            result(nil)
        case "cameraEulerAngles":
            onCameraEulerAngles(result)
            result(nil)
        case "cameraIntrinsics":
            onCameraIntrinsics(result)
        case "cameraImageResolution":
            onCameraImageResolution(result)
        case "snapshot":
            onGetSnapshot(result)
        case "capturedImage":
            onCameraCapturedImage(result)
        case "snapshotWithDepthData":
            onGetSnapshotWithDepthData(result)
        case "cameraPosition":
            onGetCameraPosition(result)
        case "onStartRecordingVideo":
            arRecordingQueue.async {
                          self.recorder?.record()
                      }
            recordingQueue.async {
                self.recordingManager?.startRecording()
            }
            
        case"onStopRecordingVideo":
            
            var arRecorderPath: String?
            var recordingIdPath: String?
            recorder?.stop { path in
                if #available(iOS 16.0, *) {
                    arRecorderPath = path.path()
                } else {
                    // Provide a fallback if needed
                    arRecorderPath = path.absoluteString // or nil
                }

                self.recordingManager?.stopRecording { recordingId in
                    if let id = recordingId {
                        recordingIdPath = id

                        // Construct response map
                        let resultMap: [String: String] = [
                            "recordingId": id,
                            "recordingPath": arRecorderPath ?? ""
                        ]

                        // Send to Flutter
                        result(resultMap)
                    } else {
                        // Send error or null
                        result(FlutterError(code: "RECORDING_FAILED", message: "Recording failed or not started", details: nil))
                    }
                }
            }

        


        default:
            result(FlutterMethodNotImplemented)
        }
    }
    

    func sendToFlutter(_ method: String, arguments: Any?) {
        DispatchQueue.main.async {
            self.channel.invokeMethod(method, arguments: arguments)
        }
    }

    
    func onDispose(_ result: FlutterResult) {
        print("Disposing AR Scene")

         sceneView.session.pause()
         sceneView.session.delegate = nil

         clearScene() // Remove all child nodes and resources
         sceneView.delegate = nil
         sceneView.removeFromSuperview()
         sceneView.scene = SCNScene()
         
         channel.setMethodCallHandler(nil)

         result(nil)
     
    }
    
    func clearScene() {
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            node.geometry?.materials.forEach { material in
                material.diffuse.contents = nil
                material.normal.contents = nil
                material.specular.contents = nil
                material.metalness.contents = nil
                material.roughness.contents = nil
            }
            node.geometry?.materials.removeAll()
            node.geometry = nil
            node.removeFromParentNode()
        }
        sceneView.scene = SCNScene() // reset scene
    }

//    func onDispose(_ result: FlutterResult) {
//        sceneView.session.pause()
//        channel.setMethodCallHandler(nil)
//        result(nil)
//    }
}
