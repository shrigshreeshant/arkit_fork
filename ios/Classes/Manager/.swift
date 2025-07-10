import ARKit
import RealityKit
import UIKit
import Flutter

class CameraViewController: UIViewController {
    
    var recordingManager: ARCameraRecordingManager?
    var arView: ARView?
    
    // Add delegate for initialization callback
    weak var initializationDelegate: CameraInitializationDelegate?
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
    
    func cleanup() {
        recordingManager = nil
        arView?.scene.anchors.removeAll()
        arView?.removeFromSuperview()
        arView = nil
    }

    deinit {
        cleanup()
        print("CameraViewController deinitialized")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        initRecordingManagerAndPerformRecordingModeRelatedSetup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    private func initRecordingManagerAndPerformRecordingModeRelatedSetup() {
        if #available(iOS 14.0, *) {
            recordingManager = ARCameraRecordingManager()
            guard let recordingManager = recordingManager else {
                print("Failed to create ARCameraRecordingManager")
                initializationDelegate?.cameraDidInitialize(success: false)
                return
            }
            
            let session = recordingManager.getSession() as! ARSession
            arView = ARView()
            guard let arView = arView else {
                print("Error: arView is not initialized yet")
                initializationDelegate?.cameraDidInitialize(success: false)
                return
            }
            
            arView.session = session
            setupPreviewView(previewView: arView)
            
            // Notify delegate that initialization is complete
            initializationDelegate?.cameraDidInitialize(success: true)
        } else {
            print("AR camera only available for iOS 14.0 or newer.")
            initializationDelegate?.cameraDidInitialize(success: false)
        }
    }
    
    private func setupPreviewView(previewView: UIView) {
        view.addSubview(previewView)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        
        let aspectRatioConstraint = previewView.widthAnchor.constraint(equalTo: previewView.heightAnchor, multiplier: 3.0/4.0)
        aspectRatioConstraint.isActive = true
        
        NSLayoutConstraint.activate([
            previewView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previewView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            previewView.widthAnchor.constraint(equalTo: view.widthAnchor),
        ])
        
        previewView.backgroundColor = .black
    }
    
    func startRecording(completion: ((Bool) -> Void)) {
        guard let recordingManager = recordingManager else {
            completion(false)
            return
        }
        recordingManager.startRecording()
        completion(true)
    }
    
    func stopRecording(completion: RecordingManagerCompletion?) {
        guard let recordingManager = recordingManager else {
            completion?(nil)
            return
        }
        recordingManager.stopRecording(completion: { recordingUUID in
            completion?(recordingUUID)
        })
    }
    
    func startLidarRecording(completion: DepthDataStartCompletion?) {
        guard let recordingManager = recordingManager else {
            completion?(nil)
            return
        }
        recordingManager.startLidarRecording(completion: completion)
    }
    
    func stopLidarRecording(completion: ((Bool) -> Void)) {
        guard let recordingManager = recordingManager else {
            completion(false)
            return
        }
        recordingManager.stopLidarRecording()
        completion(true)
    }
}
