import ARKit
import Foundation

func createWorldTrackingConfiguration(_ arguments: [String: Any]) -> ARWorldTrackingConfiguration? {
    if ARWorldTrackingConfiguration.isSupported {
        let worldTrackingConfiguration = ARWorldTrackingConfiguration()

        // Enable sceneDepth frame semantics if supported
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            worldTrackingConfiguration.frameSemantics.insert(.sceneDepth)
            print("✅ sceneDepth frame semantics enabled")
        } else {
            print("❌ sceneDepth frame semantics NOT supported on this device")
        }

        if let environmentTexturing = arguments["environmentTexturing"] as? Int {
            if environmentTexturing == 0 {
                worldTrackingConfiguration.environmentTexturing = .none
            } else if environmentTexturing == 1 {
                worldTrackingConfiguration.environmentTexturing = .manual
            } else if environmentTexturing == 2 {
                worldTrackingConfiguration.environmentTexturing = .automatic
            }
        }
        if let planeDetection = arguments["planeDetection"] as? Int {
            if planeDetection == 1 {
                worldTrackingConfiguration.planeDetection = .horizontal
            }
            if planeDetection == 2 {
                worldTrackingConfiguration.planeDetection = .vertical
            }
            if planeDetection == 3 {
                worldTrackingConfiguration.planeDetection = [.horizontal, .vertical]
            }
        }
        if let detectionImagesGroupName = arguments["detectionImagesGroupName"] as? String {
            worldTrackingConfiguration.detectionImages = ARReferenceImage.referenceImages(inGroupNamed: detectionImagesGroupName, bundle: nil)
        }
        if let detectionImages = arguments["detectionImages"] as? [[String: Any]] {
            worldTrackingConfiguration.detectionImages = parseReferenceImagesSet(detectionImages)
        }
        if let maximumNumberOfTrackedImages = arguments["maximumNumberOfTrackedImages"] as? Int {
            worldTrackingConfiguration.maximumNumberOfTrackedImages = maximumNumberOfTrackedImages
        }

        return worldTrackingConfiguration
    }
    return nil
}
