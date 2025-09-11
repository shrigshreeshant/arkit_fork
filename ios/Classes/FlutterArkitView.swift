import ARKit
import Flutter
import Foundation
import SCNRecorder


class FlutterArkitView: NSObject, FlutterPlatformView {
   

    
    let sceneView: ARSCNView
    let channel: FlutterMethodChannel
    var cameraStreamEventSink: FlutterEventSink?
    var displayLink: CADisplayLink?
    var recordingManager: ARCameraRecordingManager?=nil
    var enableSelfie=false;

    var forceTapOnCenter: Bool = false
    var configuration: ARConfiguration? = nil
    let recordingQueue = DispatchQueue(label: "recordingThread", attributes: .concurrent)



    init(
        withFrame frame: CGRect, viewIdentifier viewId: Int64, messenger msg: FlutterBinaryMessenger
    ) {
        sceneView = ARSCNView(frame: frame)
 
        self.recordingManager = ARCameraRecordingManager(sceneview: sceneView);
        
        
        let cameraStreamChannel = FlutterEventChannel(
            name: "arkit/cameraStream", binaryMessenger: msg)
        let cameraStreamHandler = CameraStreamHandler(arRecordingManager:recordingManager!)
        cameraStreamChannel.setStreamHandler(cameraStreamHandler)
   
       
        channel = FlutterMethodChannel(name: "arkit_\(viewId)", binaryMessenger: msg)

        super.init()

        sceneView.delegate = self
        channel.setMethodCallHandler(onMethodCalled)


        sceneView.prepareForRecording()



    }

    func view() -> UIView { return sceneView }

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
        case "toggleFlash":
            guard let args = arguments,
                  let toggle = args["toggleFlash"] as? Bool else {
                toggleTorch(toggle)
                return
            }
      
           
            
            
        case "selfie":
            toogleCamera()
        case "onStartRecordingVideo":
            guard let args = arguments,
                  let isArEnabled = args["isArEnabled"] as? Bool else {
                print("❌ Invalid arguments for onStartRecordingVideo")
                return
            }

       
                 recordingManager?.startRecording(isArEnabled: isArEnabled)
                print("✅ Video recording started successfully")
      
        case"onStopRecordingVideo":
            
            guard let args = arguments,
                  let isArEnabled = args["isArEnabled"] as? Bool else {
                print("❌ Invalid arguments for onStartRecordingVideo")
                return
            }
            guard let recordingManager=self.recordingManager else {
                return result("Recording manager not initialized")
            }


            recordingManager.stopRecording (completion: { (recordingId) in
              /* Process the captured video. Main thread. */
              guard let id=recordingId  else{
                  print("No Id Found error compiling video")
                  return
                
              }
                if #available(iOS 16.0, *) {
          
     
                
                    result(id)
                } else {
 
                 
                }


            },isArEnabled: isArEnabled
)
            case "startLidarRecording":
            recordingManager?.startLidarRecording()
            
            case "stopLidarRecording":
            recordingManager?.stopLidarRecording()

        


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

