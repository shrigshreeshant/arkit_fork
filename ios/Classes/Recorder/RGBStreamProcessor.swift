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
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            .transformed(by: CGAffineTransform(scaleX: StreamSettings.scale, y: StreamSettings.scale)
            .rotated(by: StreamSettings.rotation))

        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            print("RGBStreamProcessor: Failed to create CGImage")
            return nil
        }

        guard let jpegData = UIImage(cgImage: cgImage).jpegData(compressionQuality: StreamSettings.jpegQuality) else {
            print("RGBStreamProcessor: Failed to encode JPEG")
            return nil
        }

        return [
            "frameBytes": FlutterStandardTypedData(bytes: jpegData),
            "width": cgImage.width,
            "height": cgImage.height
        ]
    }
    
    var isStreaming: Bool {
        return isStreamingEnabled
    }
    
    deinit{
        stopStreaming()
        print("RGBStreamProcessor deinitialized")
    }
}
