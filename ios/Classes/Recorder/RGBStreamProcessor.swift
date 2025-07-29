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
    private let targetFPS: Double = 10.0
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

    func update(_ buffer: CVPixelBuffer) {
        guard isStreamingEnabled else { return }

        streamQueue.async {
            let now = CACurrentMediaTime()
            guard now - self.lastFrameTime >= self.frameInterval else { return }
            self.lastFrameTime = now
            
            autoreleasepool {
                guard let frameData = self.processFrame(buffer) else { return }
                DispatchQueue.main.async {
                    self.eventSink?(frameData)
                }
            }
        }
    }
    private func processFrame(_ pixelBuffer: CVPixelBuffer) -> [String: Any]? {
        autoreleasepool {
            // Step 1: Create CIImage and apply scale + rotation
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let transform = CGAffineTransform(scaleX: 0.3, y: 0.3).rotated(by: -.pi / 2)
            let transformedImage = ciImage.transformed(by: transform)

            // Step 2: Get original extent
            let extent = transformedImage.extent
            let originalWidth = extent.width
            let originalHeight = extent.height
            let desiredAspectRatio: CGFloat = 1

            // Step 3: Compute crop size maintaining aspect ratio
            var cropWidth = originalWidth
            var cropHeight = cropWidth / desiredAspectRatio

            if cropHeight > originalHeight {
                cropHeight = originalHeight
                cropWidth = cropHeight * desiredAspectRatio
            }

            // Step 4: Center crop rectangle
            let cropX = extent.midX - cropWidth / 2
            let cropY = extent.midY - cropHeight / 2
            let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)

            // Step 5: Crop image
            let croppedImage = transformedImage.cropped(to: cropRect)

            // Step 6: Convert to CGImage
            guard let cgImage = ciContext.createCGImage(croppedImage, from: croppedImage.extent) else {
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
                "frameBytes": FlutterStandardTypedData(bytes: jpegData),
                "width": Int(cropWidth),
                "height": Int(cropHeight)
            ]
        }
    }


//    private func processFrame(_ pixelBuffer: CVPixelBuffer) -> [String: Any]? {
//        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
//            .transformed(by: CGAffineTransform(scaleX: StreamSettings.scale, y: StreamSettings.scale)
//            .rotated(by: StreamSettings.rotation))
//
//        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
//            print("RGBStreamProcessor: Failed to create CGImage")
//            return nil
//        }
//
//        guard let jpegData = UIImage(cgImage: cgImage).jpegData(compressionQuality: StreamSettings.jpegQuality) else {
//            print("RGBStreamProcessor: Failed to encode JPEG")
//            return nil
//        }
//
//        return [
//            "frameBytes": FlutterStandardTypedData(bytes: jpegData),
//            "width": cgImage.width,
//            "height": cgImage.height
//        ]
//    }
    
    var isStreaming: Bool {
        return isStreamingEnabled
    }
    
    deinit{
        stopStreaming()
        print("RGBStreamProcessor deinitialized")
    }
}
