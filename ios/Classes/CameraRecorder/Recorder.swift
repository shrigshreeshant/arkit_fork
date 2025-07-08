// //
// //  Recorder.swift
// //  Pods
// //
// //  Created by shreeshant prajapati on 07/07/2025.
// //


// import Foundation
// import ARKit
// import UIKit
// import Photos

// class Recorder {
    
//     static func captureImage(from sceneView: ARSCNView, saveToPhotos: Bool = false, completion: @escaping (UIImage?) -> Void) {
//         DispatchQueue.main.async {
//             let image = sceneView.snapshot()
//             if saveToPhotos, let image = image {
//                 saveImageToPhotos(image)
//             }
//             completion(image)
//         }
//     }

//     private static func saveImageToPhotos(_ image: UIImage) {
//         PHPhotoLibrary.shared().performChanges({
//             PHAssetChangeRequest.creationRequestForAsset(from: image)
//         }) { success, error in
//             if let error = error {
//                 print("❌ Error saving image to Photos: \(error.localizedDescription)")
//             } else if success {
//                 print("✅ Image saved to Photos successfully.")
//             }
//         }
//     }
// }
