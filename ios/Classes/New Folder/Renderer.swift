//
//  Renderer.swift
//  Pods
//
//  Created by shreeshant prajapati on 09/07/2025.
//

//  Renderer.swift
//  ARSceneKitRecording
//
//  Created by OpenAI Assistant.

import Foundation
import ARKit
import SceneKit
import Metal
import CoreVideo
import CoreImage

class Renderer {
    private let device: MTLDevice
    private let ciContext: CIContext
    private let renderer: SCNRenderer
    private let bufferPool: CVPixelBufferPool
    private let renderSize: CGSize

    init?(sceneView: ARSCNView, size: CGSize) {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.device = device
        self.ciContext = CIContext(mtlDevice: device)
        self.renderer = SCNRenderer(device: device, options: nil)
        self.renderer.scene = sceneView.scene
        self.renderer.pointOfView = sceneView.pointOfView
        self.renderSize = size

        guard let pool = Renderer.createPixelBufferPool(width: Int(size.width), height: Int(size.height)) else {
            return nil
        }
        self.bufferPool = pool
    }

    private static func createPixelBufferPool(width: Int, height: Int) -> CVPixelBufferPool? {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
        return pool
    }

    func renderFrame(time: TimeInterval = CACurrentMediaTime()) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, bufferPool, &pixelBuffer)

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(renderSize.width),
            height: Int(renderSize.height),
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]

        guard let commandQueue = device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        passDescriptor.colorAttachments[0].storeAction = .store

        renderer.render(
            atTime: time,
            viewport: CGRect(origin: .zero, size: renderSize),
            commandBuffer: commandBuffer,
            passDescriptor: passDescriptor
        )

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard let ciImage = CIImage(mtlTexture: texture, options: nil) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])

        // Flip vertically to correct orientation
        let flippedImage = ciImage.transformed(by:
            CGAffineTransform(scaleX: 1, y: -1)
                .translatedBy(x: 0, y: -ciImage.extent.height))

        ciContext.render(flippedImage, to: buffer)
        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }
}

