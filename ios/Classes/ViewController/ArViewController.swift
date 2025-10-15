//
//  sceneViewController.swift
//  Pods
//
//  Created by shreeshant prajapati on 15/10/2025.
//

import ARKit
import SceneKit
import UIKit
import Flutter


protocol CameraInitializationDelegate: AnyObject {
    func cameraDidInitialize(success: Bool)
}

class ARViewController: UIViewController {
    
    var recordingManager: ARCameraRecordingManager?
    var sceneView: ARSCNView?
    
    // Add delegate for initialization callback
    weak var initializationDelegate: CameraInitializationDelegate?
    
    init() {
        print("ARViewController initialized")
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
    
    func cleanup() {
        
        if let scView = self.sceneView {
            // 2. Stop and clean up AR session
            scView.session.pause()
            scView.session.delegate = nil
            
            // 3. Clean up scene view delegates
            scView.delegate = nil
            // 6. Clean up all nodes and their resources
            scView.scene.rootNode.enumerateChildNodes { node, _ in
                // Clean up materials
                node.geometry?.materials.forEach { material in
                    material.diffuse.contents = nil
                    material.normal.contents = nil
                    material.specular.contents = nil
                    material.metalness.contents = nil
                    material.roughness.contents = nil
                    material.emission.contents = nil
                    material.ambientOcclusion.contents = nil
                }
                node.geometry?.materials.removeAll()
                node.geometry = nil
                
                // Remove animations
                node.removeAllAnimations()
                node.removeAllAudioPlayers()
                
                // Remove from parent
                node.removeFromParentNode()
            }
            
            // 8. Remove animations and views
            scView.layer.removeAllAnimations()
            scView.removeFromSuperview()
            sceneView = nil
        }
        recordingManager = nil

    }

    deinit {
        cleanup()
        print("ARViewController deinitialized")
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
    
    
    private func setupPreviewView(previewView: UIView) {
           view.addSubview(previewView)
           previewView.translatesAutoresizingMaskIntoConstraints = false
           
           let aspectRatioConstraint = previewView.widthAnchor.constraint(equalTo: previewView.heightAnchor, multiplier: 9/16)
           aspectRatioConstraint.isActive = true
           
           NSLayoutConstraint.activate([
               previewView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
               previewView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
               previewView.widthAnchor.constraint(equalTo: view.widthAnchor),
           ])
           
           previewView.backgroundColor = .black
       }
    private func initRecordingManagerAndPerformRecordingModeRelatedSetup() {
        if #available(iOS 14.0, *) {

            
            sceneView = ARSCNView()
            sceneView?.prepareForRecording()
            
           
            guard let sceneView = sceneView else {
                print("Error: sceneView is not initialized yet")
                initializationDelegate?.cameraDidInitialize(success: false)
                return
            }
            recordingManager = ARCameraRecordingManager(sceneview: sceneView)
            guard let _ = recordingManager else {
                print("Failed to create ARCameraRecordingManager")
                initializationDelegate?.cameraDidInitialize(success: false)
                return
            }
            
            setupPreviewView(previewView: sceneView)
            // Notify delegate that initialization is complete
            initializationDelegate?.cameraDidInitialize(success: true)
        } else {
            print("AR camera only available for iOS 14.0 or newer.")
            initializationDelegate?.cameraDidInitialize(success: false)
        }
    }

}
