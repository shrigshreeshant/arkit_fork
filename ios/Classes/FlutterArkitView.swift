import ARKit
import Flutter
import Foundation
import SCNRecorder


class FlutterArkitView: NSObject, FlutterPlatformView {
   
    private var _view: UIView
    weak var viewController: ARViewController?
     let channel: FlutterMethodChannel
    private var eventChannel: FlutterEventChannel?
    private var pendingEventSink: FlutterEventSink?
    private var isViewCreated = false
    private var isInitialized = false
    
    // Loading state management
    private var loadingIndicator: UIActivityIndicatorView?
    private var isWaitingForViewController = false
    

    var enableSelfie=false;
    

    var forceTapOnCenter: Bool = false
    var configuration: ARConfiguration? = nil
    var isArEnabled: Bool = false


    
    init(
          frame: CGRect,
          viewIdentifier viewId: Int64,
          arguments args: Any?,
          binaryMessenger messenger: FlutterBinaryMessenger
      ) {
          self._view = UIView()
          self.channel = FlutterMethodChannel(name: "arkit_\(viewId)", binaryMessenger: messenger)
          super.init()
          self.channel.setMethodCallHandler(onMethodCalled)

          self.eventChannel = FlutterEventChannel(name: "arkit/cameraStream", binaryMessenger: messenger)
          self.eventChannel?.setStreamHandler(self)

          // Show loading and attempt to create view
          showLoadingState()
          attemptToCreateNativeView()
          
           print("FlutterArkitView initialized")
      }

    deinit{
        performDisposal()
        print("FlutterArkitView deinitialized")
        
    }
    func view() -> UIView { return _view }
    
    private func showLoadingState() {
           // Activity indicator
           let indicator = UIActivityIndicatorView(style: .medium)
           indicator.color = .white
           indicator.translatesAutoresizingMaskIntoConstraints = false
           indicator.startAnimating()
                   
           // Add container to main view
           _view.addSubview(indicator)
           
           // Setup constraints
           NSLayoutConstraint.activate([
               indicator.centerXAnchor.constraint(equalTo: _view.centerXAnchor),
               indicator.centerYAnchor.constraint(equalTo: _view.centerYAnchor),
           
           ])
           // Store references
           self.loadingIndicator = indicator
       }
       
       private func hideLoadingState() {
           loadingIndicator?.stopAnimating()
           loadingIndicator = nil
       }
       

       private func attemptToCreateNativeView() {
           guard !isViewCreated && !isWaitingForViewController else { return }
           
           isWaitingForViewController = true
           
           // Use the executeWhenViewControllerReady method
           UIApplication.shared.executeWhenViewControllerReady(
               maxRetries: 15,
               delay: 0.1
           ) {
               DispatchQueue.main.async {
                   self.isWaitingForViewController = false
                   self.createNativeView()
               }
           }
       }

       private func createNativeView() {
           guard !isViewCreated else { return }
           isViewCreated = true
                   
           guard let topController = UIApplication.shared.keyWindowPresentedController else {
               print("Failed to get root view controller after retries")
               self.sendToFlutter("onError", arguments: "Failed to get view controller")
               return
           }
           
           let vc = ARViewController()
           // Set up the delegate before adding as child
           vc.initializationDelegate = self
           self.viewController = vc

           // Properly add as child view controller
           topController.addChild(vc)
           
           guard let cameraView = vc.view else {
               print("Failed to get camera view")
               vc.removeFromParent()
               self.sendToFlutter("onError", arguments: "Failed to get camera view")
               return
           }
           
           cameraView.translatesAutoresizingMaskIntoConstraints = false
           _view.addSubview(cameraView)

           NSLayoutConstraint.activate([
               cameraView.leadingAnchor.constraint(equalTo: _view.leadingAnchor),
               cameraView.trailingAnchor.constraint(equalTo: _view.trailingAnchor),
               cameraView.topAnchor.constraint(equalTo: _view.topAnchor),
               cameraView.bottomAnchor.constraint(equalTo: _view.bottomAnchor)
           ])

           vc.didMove(toParent: topController)
       }
       
       @objc private func retryInitialization() {
           // Reset state
           isViewCreated = false
           isInitialized = false
           isWaitingForViewController = false
           
           // Clear existing view controller
           if let vc = viewController {
               vc.initializationDelegate = nil
               vc.cleanup()
               vc.willMove(toParent: nil)
               vc.view?.removeFromSuperview()
               vc.removeFromParent()
               viewController = nil
           }
           
           // Reset loading state
           loadingIndicator?.isHidden = false
           loadingIndicator?.color = .white
           loadingIndicator?.startAnimating()
           
           // Retry
           attemptToCreateNativeView()
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
        case "toggleFlash":
            guard let args = arguments,
                  let toggle = args["toggleFlash"] as? Bool else {
          
                return
            }
      
            toggleTorch(toggle)

        case "selfie":
            #if !DISABLE_TRUEDEPTH_API
                toggleCamera()
            #else
                logPluginError("TRUEDEPTH_API disabled", toChannel: channel)
            #endif
        case "toggleAr":
            isArEnabled = !isArEnabled
            guard let rm=viewController?.recordingManager else{return}
            rm.setArEnableDuringRecording(isArEnabled)
        case "onStartRecordingVideo":
            guard let rm=viewController?.recordingManager else{return}

            rm.startRecording(isArEnabled: isArEnabled)
            print("✅ Video recording started successfully")
      
        case"onStopRecordingVideo":
            
            guard let rm=viewController?.recordingManager else{return}


            rm.stopRecording (completion: { (recordingId) in
              /* Process the captured video. Main thread. */
              guard let id=recordingId  else{
                  print("No Id Found error compiling video")
                  return
                
              }
            result(id)
            },isArEnabled: isArEnabled
)
 
            case "recordGoodFrame":
            guard let rm=viewController?.recordingManager else{return}

            rm.recordGoodFrames(arguments!)

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
        performDisposal()
        result(nil)
     
    }
    
    
    
    private func performDisposal() {
        channel.setMethodCallHandler(nil)
        eventChannel?.setStreamHandler(nil)
        eventChannel = nil
        pendingEventSink = nil

        if let vc = viewController {
            vc.initializationDelegate = nil
            vc.cleanup()
            vc.willMove(toParent: nil)
            vc.view?.removeFromSuperview()
            vc.removeFromParent()
            viewController = nil
        }

        _view.subviews.forEach { $0.removeFromSuperview() }
        hideLoadingState()
        isViewCreated = false
        isInitialized = false
        isWaitingForViewController = false
    }

}



// MARK: - CameraInitializationDelegate
extension FlutterArkitView: CameraInitializationDelegate {
    func cameraDidInitialize(success: Bool) {
        DispatchQueue.main.async {
            self.isInitialized = success
            
            if success {
                // Hide loading state when successfully initialized
                self.hideLoadingState()
                
                // Apply pending event sink now that recording manager is ready
                if let eventSink = self.pendingEventSink,
                   let recordingManager = self.viewController?.recordingManager {
                    recordingManager.rgbStreamer.setEventSink(eventSink)
                    self.pendingEventSink = nil
                }
                self.sendToFlutter("onViewInitialized", arguments: nil)
            } else {
                self.sendToFlutter("onError", arguments: "Failed to initialize camera")
            }
        }
    }
}

// MARK: - FlutterStreamHandler
extension FlutterArkitView: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if let cameraVC = viewController,
           let recordingManager = cameraVC.recordingManager,
           isInitialized {
            recordingManager.rgbStreamer.setEventSink(events)
        } else {
            // Store for later when initialization completes
            pendingEventSink = events
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let vc = viewController {
            vc.recordingManager?.rgbStreamer.setEventSink(nil)
        }
        pendingEventSink = nil
        return nil
    }
}
