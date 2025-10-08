//
//  RGBStreamProcessor.swift
//  Pods
//
//  Created by Shrig0001 on 23/05/2025.
//


//
//  RGBStreamProcessor.swift
//

import Foundation
import Flutter
import UIKit
import CoreImage
import Metal
import AVFoundation

class RGBStreamProcessor {
    
    private let streamQueue = DispatchQueue(label: "rgb.stream.processor.queue")
    private var eventSink: FlutterEventSink?
    private var isStreamingEnabled = false
    
    private var lastFrameTime = CACurrentMediaTime()
    private let targetFPS: Double = 20.0
    private var frameInterval: CFTimeInterval { 1.0 / targetFPS }
    
    private lazy var ciContext: CIContext = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal device not available")
        }
        return CIContext(mtlDevice: device, options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .cacheIntermediates: false
        ])
    }()
    
    private struct StreamSettings {
        static let scale: CGFloat = 0.3
        static let jpegQuality: CGFloat = 0.35
        static let rotation: CGFloat = -.pi / 2
    }

    func setEventSink(_ sink: FlutterEventSink?) {
        if let sink = sink {
            startStreaming(eventSink: sink)
        } else {
            stopStreaming()
        }
    }
    
    func startStreaming(eventSink: @escaping FlutterEventSink) {
        print("RGBStreamProcessor: Starting streaming at \(targetFPS) FPS")
        self.eventSink = eventSink
        self.isStreamingEnabled = true
    }
    
    func stopStreaming() {
        print("RGBStreamProcessor: Stopping streaming")
        self.eventSink = nil
        self.isStreamingEnabled = false
    }

    func update(_ buffer: CVPixelBuffer,_ numOfRecordedFrames: Int,_ timestamp: CMTime) {
        guard isStreamingEnabled else { return }

        streamQueue.async {
            let now = CACurrentMediaTime()
            guard now - self.lastFrameTime >= self.frameInterval else { return }
            self.lastFrameTime = now
            
            autoreleasepool {
                guard let frameData = self.processFrame(buffer,numOfRecordedFrames,timestamp) else { return }
                
                DispatchQueue.main.async {
                    self.eventSink?(frameData)
                }
            }
        }
    }
    private func processFrame(_ pixelBuffer: CVPixelBuffer,_ numOfRecordedFrames: Int,_ timestamp: CMTime) -> [String:Any]? {
        autoreleasepool {
     
            // Step 1: Create CIImage and apply scale + rotation
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let transform = CGAffineTransform(scaleX: 0.3, y: 0.3).rotated(by: -.pi / 2)
            let transformedImage = ciImage.transformed(by: transform)
//
//            // Step 2: Get original extent
//            let extent = transformedImage.extent
//            let originalWidth = extent.width
//            let originalHeight = extent.height
//            let desiredAspectRatio: CGFloat = 0.9225
//
//            // Step 3: Compute crop size maintaining aspect ratio
//            var cropWidth = originalWidth
//            var cropHeight = cropWidth / desiredAspectRatio
//
//            if cropHeight > originalHeight {
//                cropHeight = originalHeight
//                cropWidth = cropHeight * desiredAspectRatio
//            }
//
//            // Step 4: Center crop rectangle
//            let cropX = extent.midX - cropWidth / 2
//            let cropY = extent.midY - cropHeight / 2
//            let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
//
//            // Step 5: Crop image
//            let croppedImage = transformedImage.cropped(to: cropRect)

            // Step 6: Convert to CGImage
            guard let cgImage = ciContext.createCGImage(transformedImage, from: transformedImage.extent) else {
                print("RGBStreamProcessor: Failed to create CGImage")
                return nil
            }

            // Step 7: Encode to JPEG
            guard let jpegData = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.35) else {
                print("RGBStreamProcessor: Failed to encode JPEG")
                return nil
            }

            // Step 8: Return result
            return [
                "frameNumber": numOfRecordedFrames,
                "timestamp": CMTimeGetSeconds(timestamp),
                "imageData": FlutterStandardTypedData(bytes
                                                    :jpegData) // send as base64 string
            ]
            
            
        }
    }

    var isStreaming: Bool {
        return isStreamingEnabled
    }
    
    deinit{
        stopStreaming()
        print("RGBStreamProcessor deinitialized")
    }
}
