//
//  AudioUtils.swift
//
//
//  Created by shreeshant prajapati on 18/08/2025.
//

import Foundation
import AVFoundation

class AudioUtils {
    
    // MARK: - Error Types
    enum AudioUtilsError: Error {
        case noAudioTrackInSource
        case noVideoTrackInTarget
        case exportFailed
        case invalidURL
        case assetLoadingFailed
    }
    
    // MARK: - Properties
    private let processingQueue = DispatchQueue(label: "AudioUtils.Processing", qos: .userInitiated)
    
    // MARK: - Initializer
    init() {}
    
    // MARK: - Public Methods
    
    /// Updates the RGB video by adding audio from the AR video (replaces the original RGB video)
    /// - Parameters:
    ///   - arVideoURL: URL of the AR video (source of audio)
    ///   - rgbVideoURL: URL of the RGB video that will be updated with audio
    ///   - completion: Completion handler with result (returns the same rgbVideoURL)
    func updateRGBVideoWithAudio(
        from arVideoURL: URL,
        rgbVideoURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        processingQueue.async {
            do {
                try self.performRGBVideoUpdate(arVideoURL: arVideoURL, rgbVideoURL: rgbVideoURL)
                DispatchQueue.main.async {
                    completion(.success(rgbVideoURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Simple method to update RGB video with AR audio (modifies original file)
    /// - Parameters:
    ///   - arVideoURL: Source video with audio to copy
    ///   - rgbVideoURL: RGB video that will be updated with audio
    ///   - completion: Called when the RGB video has been updated
    func addAudioToRGBVideo(
        arVideoURL: URL,
        rgbVideoURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        updateRGBVideoWithAudio(
            from: arVideoURL,
            rgbVideoURL: rgbVideoURL,
            completion: completion
        )
    }
    
    /// Get info about video assets before processing
    /// - Parameters:
    ///   - arVideoURL: AR video URL
    ///   - nonARVideoURL: Non-AR video URL
    ///   - completion: Returns info about both videos
    func getVideoInfo(
        arVideoURL: URL,
        nonARVideoURL: URL,
        completion: @escaping (ARVideoInfo?, NonARVideoInfo?) -> Void
    ) {
        processingQueue.async {
            let arAsset = AVAsset(url: arVideoURL)
            let nonARAsset = AVAsset(url: nonARVideoURL)
            
            let arInfo = ARVideoInfo(
                duration: arAsset.duration,
                hasAudio: !arAsset.tracks(withMediaType: .audio).isEmpty,
                hasVideo: !arAsset.tracks(withMediaType: .video).isEmpty
            )
            
            let nonARInfo = NonARVideoInfo(
                duration: nonARAsset.duration,
                hasAudio: !nonARAsset.tracks(withMediaType: .audio).isEmpty,
                hasVideo: !nonARAsset.tracks(withMediaType: .video).isEmpty
            )
            
            DispatchQueue.main.async {
                completion(arInfo, nonARInfo)
            }
        }
    }
    
    /// Check if a video file has audio track
    /// - Parameters:
    ///   - videoURL: URL of the video to check
    ///   - completion: Returns true if video has audio, false otherwise
    func hasAudioTrack(
        videoURL: URL,
        completion: @escaping (Bool) -> Void
    ) {
        processingQueue.async {
            let asset = AVAsset(url: videoURL)
            let hasAudio = !asset.tracks(withMediaType: .audio).isEmpty
            
            DispatchQueue.main.async {
                completion(hasAudio)
            }
        }
    }
    
    // MARK: - Private Methods


    private func performRGBVideoUpdate(
        arVideoURL: URL,
        rgbVideoURL: URL
    ) throws {
        
        print("🔹 Starting RGB video update with AR audio")
        print("RGB video URL: \(rgbVideoURL)")
        print("AR video URL: \(arVideoURL)")
        
        // Load both assets
        let arAsset = AVAsset(url: arVideoURL)
        let rgbAsset = AVAsset(url: rgbVideoURL)
        
        // Validate audio track in AR video
        guard let arAudioTrack = arAsset.tracks(withMediaType: .audio).first else {
            print("❌ No audio track found in AR video")
            throw AudioUtilsError.noAudioTrackInSource
        }
        print("✅ AR audio track found with duration: \(CMTimeGetSeconds(arAsset.duration))s")
        
        // Validate video track in RGB video
        guard let rgbVideoTrack = rgbAsset.tracks(withMediaType: .video).first else {
            print("❌ No video track found in RGB video")
            throw AudioUtilsError.noVideoTrackInTarget
        }
        print("✅ RGB video track found with duration: \(CMTimeGetSeconds(rgbAsset.duration))s")
        
        // Create temporary output URL
        let tempURL = rgbVideoURL.appendingPathExtension("temp")
        print("🔹 Temporary output URL: \(tempURL)")
        
        // Create composition
        let composition = AVMutableComposition()
        
        // Add video track from RGB video
        let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        // Add audio track from AR video
        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        // Calculate final duration
        let videoDuration = rgbAsset.duration
        let audioDuration = arAsset.duration
        let finalDuration = CMTimeMinimum(videoDuration, audioDuration)
        print("🔹 Final duration for merged video: \(CMTimeGetSeconds(finalDuration))s")
        
        // Insert video track
        try compositionVideoTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: finalDuration),
            of: rgbVideoTrack,
            at: .zero
        )
        print("✅ RGB video track inserted into composition")
        
        // Insert AR audio track
        try compositionAudioTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: finalDuration),
            of: arAudioTrack,
            at: .zero
        )
        print("✅ AR audio track inserted into composition")
        
        // Optionally preserve existing RGB audio
        if let existingAudioTrack = rgbAsset.tracks(withMediaType: .audio).first {
            let secondAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            try secondAudioTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: finalDuration),
                of: existingAudioTrack,
                at: .zero
            )
            print("✅ Preserved existing RGB audio track")
        }
        
        // Export to temporary location
        if let videoComposition = createVideoComposition(for: composition, sourceVideoTrack: rgbVideoTrack) {
            print("🔹 Exporting with video composition (rotation applied)")
            try exportComposition(composition, videoComposition: videoComposition, to: tempURL)
        } else {
            print("🔹 Exporting without video composition")
            try exportComposition(composition, videoComposition: nil, to: tempURL)
        }
        
        // Replace original file
        try replaceOriginalFile(originalURL: rgbVideoURL, temporaryURL: tempURL)
        print("✅ Replaced original RGB video with updated file containing AR audio")
        print("🔹 RGB video update completed successfully")
    }

    
    private func createVideoComposition(
        for composition: AVMutableComposition,
        sourceVideoTrack: AVAssetTrack
    ) -> AVMutableVideoComposition? {
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = sourceVideoTrack.naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30 FPS
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        
        if let compositionVideoTrack = composition.tracks(withMediaType: .video).first {
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)

            instruction.layerInstructions = [layerInstruction]
        }
        
        videoComposition.instructions = [instruction]
        return videoComposition
    }
    
    private func exportComposition(
        _ composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition?,
        to outputURL: URL
    ) throws {
        
        print("🔹 Exporting composition to \(outputURL)")
        
        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw AudioUtilsError.exportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        var finalVideoComposition: AVMutableVideoComposition? = videoComposition
        
        // Apply -90° rotation if videoComposition exists
        if let compositionTrack = composition.tracks(withMediaType: .video).first {
            let rotatedVideoComposition = AVMutableVideoComposition()
            let naturalSize = compositionTrack.naturalSize
            rotatedVideoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            
            // Swap width & height for rotation
            rotatedVideoComposition.renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
            
            // Rotate by 90 degrees
            var transform = CGAffineTransform(rotationAngle: .pi/2)
            // Move the rotated video back into frame
            transform = transform.translatedBy(x: 0, y: -naturalSize.height)
            layerInstruction.setTransform(transform, at: .zero)
            instruction.layerInstructions = [layerInstruction]
            rotatedVideoComposition.instructions = [instruction]
            
            finalVideoComposition = rotatedVideoComposition
            print("🔹 Applied -90° rotation to video")
        }
        
        exportSession.videoComposition = finalVideoComposition
        
        // Use semaphore to make this synchronous
        let semaphore = DispatchSemaphore(value: 0)
        var exportError: Error?
        
        exportSession.exportAsynchronously {
            if exportSession.status != .completed {
                exportError = exportSession.error ?? AudioUtilsError.exportFailed
                print("❌ Export failed: \(String(describing: exportSession.error))")
            } else {
                print("✅ Export completed successfully")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = exportError {
            throw error
        }
        
        guard exportSession.status == .completed else {
            throw AudioUtilsError.exportFailed
        }
    }
    
    private func replaceOriginalFile(originalURL: URL, temporaryURL: URL) throws {
        // Remove the original file
        try FileManager.default.removeItem(at: originalURL)
        
        // Move temporary file to original location
        try FileManager.default.moveItem(at: temporaryURL, to: originalURL)
    }
}

// MARK: - Helper Structs
struct ARVideoInfo {
    let duration: CMTime
    let hasAudio: Bool
    let hasVideo: Bool
    
    var durationInSeconds: Double {
        return CMTimeGetSeconds(duration)
    }
}

struct NonARVideoInfo {
    let duration: CMTime
    let hasAudio: Bool
    let hasVideo: Bool
    
    var durationInSeconds: Double {
        return CMTimeGetSeconds(duration)
    }
}

// MARK: - Static Convenience Methods
extension AudioUtils {
    
    /// Static convenience method to update RGB video with AR audio
    /// - Parameters:
    ///   - arVideoURL: Source video with audio to copy
    ///   - rgbVideoURL: RGB video that will be updated with audio
    ///   - completion: Called when the RGB video has been updated
    static func updateRGBVideo(
        with arVideoURL: URL,
        rgbVideoURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let audioUtils = AudioUtils()
        audioUtils.updateRGBVideoWithAudio(
            from: arVideoURL,
            rgbVideoURL: rgbVideoURL,
            completion: completion
        )
    }
}
