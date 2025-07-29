import ARKit
import Flutter
import Foundation
import SCNRecorder


class FlutterArkitView: NSObject, FlutterPlatformView {

    
    let sceneView: ARSCNView
    let channel: FlutterMethodChannel
    var cameraStreamEventSink: FlutterEventSink?
    var displayLink: CADisplayLink?
    var recordingManger: ARCameraRecordingManager?=nil

    var forceTapOnCenter: Bool = false
    var configuration: ARConfiguration? = nil
    let recordingQueue = DispatchQueue(label: "recordingThread", attributes: .concurrent)
    let arRecordingQueue = DispatchQueue(label: "arRecordingThread", attributes: .concurrent)


    init(
        withFrame frame: CGRect, viewIdentifier viewId: Int64, messenger msg: FlutterBinaryMessenger
    ) {
        sceneView = ARSCNView(frame: frame)
 

   
       
        channel = FlutterMethodChannel(name: "arkit_\(viewId)", binaryMessenger: msg)

        super.init()

        sceneView.delegate = self
        channel.setMethodCallHandler(onMethodCalled)


        sceneView.prepareForRecording()


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
                do {
                    self.recordingManger?.startRecording()
                    print("✅ Video recording started successfully")
                }
            }
//            recordingQueue.async {
//                self.recordingManager?.startRecording()
//            }
            
        case"onStopRecordingVideo":
            guard let recordingManger=self.recordingManger else {
                return result("Recording manager not initialized")
            }


          recordingManger.stopRecording { (recordingId) in
              /* Process the captured video. Main thread. */
              guard let id=recordingId  else{
                  print("No Id Found error compiling video")
                  return
                
              }
                if #available(iOS 16.0, *) {
          
     
                    let resultMap: [String: String] = [
                        "recordingId": id,
          
                    ]
                    result(resultMap)
                } else {
 
                 
                }


            }

            case "startLidarRecording":
            recordingManger?.startLidarRecording()
            
            case "stopLidarRecording":
            recordingManger?.stopLidarRecording()

        


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
}

