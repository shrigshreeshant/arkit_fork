//
//  ThumbnailGenerator.swift
//  Pods
//
//  Created by shreeshant prajapati on 21/07/2025.
//
import UIKit
import CoreVideo
import CoreImage

class ThumbnailGenerator {
    private let context = CIContext()
    private var thumbnailPath: String?

    /// Saves the first CVPixelBuffer as a JPEG thumbnail image, rotated 90 degrees clockwise.
    ///
    /// - Parameters:
    ///   - pixelBuffer: The frame to use for thumbnail.
    ///   - dirPath: Directory where thumbnail should be saved.
    ///   - recordingId: ID used to name the thumbnail file.
    func getThumbnailPath(
        pixelBuffer: CVPixelBuffer,
        toDirectory dirPath: String,
        recordingId: String
    ) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Rotate 90° clockwise (translate to maintain visible frame)
        let transform = CGAffineTransform(translationX: ciImage.extent.height, y: 0)
            .rotated(by: -.pi / 2)

        let rotatedImage = ciImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(rotatedImage, from: rotatedImage.extent) else {
            print("❌ ThumbnailGenerator: Failed to convert pixel buffer to CGImage")
            return
        }

        let uiImage = UIImage(cgImage: cgImage)

        guard let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            print("❌ ThumbnailGenerator: Failed to create JPEG data")
            return
        }

        let filename = "\(recordingId)_thumbnail.jpg"
        let thumbnailFullPath = (dirPath as NSString).appendingPathComponent(filename)

        do {
            try jpegData.write(to: URL(fileURLWithPath: thumbnailFullPath))
            thumbnailPath = thumbnailFullPath
            print("✅ ThumbnailGenerator: Saved thumbnail at \(thumbnailFullPath)")
        } catch {
            print("❌ ThumbnailGenerator: Error writing thumbnail to disk: \(error)")
        }
    }

    func reset() {
        thumbnailPath = nil
    }

    func getSavedPath() -> String? {
        return thumbnailPath
    }
}
