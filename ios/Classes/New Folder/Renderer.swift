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
    
    // Performance optimizations: Reuse expensive resources
    private let commandQueue: MTLCommandQueue
    private var textureCache: MTLTexture?
    private let renderPassDescriptor = MTLRenderPassDescriptor()
    private var metalTextureCache: CVMetalTextureCache?
    
    // Pre-computed transform for image flipping
    private let flipTransform: CGAffineTransform
    
    // Async rendering support
    private let renderQueue = DispatchQueue(label: "com.renderer.metal", qos: .userInitiated)
    private var isRendering = false

    init?(sceneView: ARSCNView, size: CGSize) {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.device = device

        
        // Create command queue once
        guard let commandQueue = device.makeCommandQueue() else { return nil }
        self.commandQueue = commandQueue
        let colorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
        // Optimize CIContext creation
        let ciOptions: [CIContextOption: Any] = [
            .workingColorSpace: colorSpace,
            .cacheIntermediates: false,
            .useSoftwareRenderer: false
        ]
        self.ciContext = CIContext(mtlDevice: device, options: ciOptions)
        
        self.renderer = SCNRenderer(device: device, options: nil)
        self.renderer.scene = sceneView.scene
        self.renderer.pointOfView = sceneView.pointOfView
        renderer.delegate = sceneView.delegate  // ✅ Correct delegate

        // But also check:
        renderer.isJitteringEnabled = sceneView.isJitteringEnabled
   
        self.renderSize = size
//        self.renderer.pointOfView?.camera = SCNCamera()
//        
        // Pre-compute flip transform
        self.flipTransform = CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -size.height)

        guard let pool = Renderer.createPixelBufferPool(width: Int(size.width), height: Int(size.height)) else {
            return nil
        }
        self.bufferPool = pool
        
        // Create Metal texture cache for better performance
        CVMetalTextureCacheCreate(nil, nil, device, nil, &metalTextureCache)
        
        // Pre-create reusable texture
        createReusableTexture()
      
    }
    private var hasSetProjectionMatrix = false
    func updateCameraProjection(from arFrame: ARFrame) {
        guard let camera = renderer.pointOfView?.camera else {
            print("⚠️ No camera found on pointOfView")
            return
        }
        



        if hasSetProjectionMatrix {
            print("ℹ️ Skipping projection update — already set")
            return
        }

        let viewportSize = CGSize(width: 1920, height: 1440)
        print("📐 Setting projection matrix for viewport: \(viewportSize.width)x\(viewportSize.height)")

        let matrix = arFrame.camera.projectionMatrix(
            for: .landscapeLeft,
            viewportSize: viewportSize,
            zNear: 0.001,
            zFar: 1000
        )

        camera.projectionTransform = SCNMatrix4(matrix)
        hasSetProjectionMatrix = true


        // Compact matrix log
        let elements = [
            matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
            matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
            matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
            matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w,
        ]
        let formatted = elements.map { String(format: "%.3f", $0) }.joined(separator: ", ")
        print("✅ Projection matrix set: [\(formatted)]")
    }

    private func createReusableTexture() {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(renderSize.width),
            height: Int(renderSize.height),
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        
        self.textureCache = device.makeTexture(descriptor: descriptor)
    }

    private static func createPixelBufferPool(width: Int, height: Int) -> CVPixelBufferPool? {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        var pool: CVPixelBufferPool?
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]
        
        CVPixelBufferPoolCreate(nil, poolAttributes as CFDictionary, attributes as CFDictionary, &pool)
        return pool
    }

    func renderFrame(time: TimeInterval = CACurrentMediaTime()) -> CVPixelBuffer? {
        // Prevent multiple concurrent renders
        guard !isRendering else { return nil }
        isRendering = true
        defer { isRendering = false }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, bufferPool, &pixelBuffer)

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        // Validate texture cache
        guard let texture = textureCache,
              texture.width == Int(renderSize.width),
              texture.height == Int(renderSize.height) else {
            createReusableTexture()
            guard let newTexture = textureCache else { return nil }
            return renderToBuffer(buffer: buffer, texture: newTexture, time: time)
        }
        
        return renderToBuffer(buffer: buffer, texture: texture, time: time)
    }
    
    private func renderToBuffer(buffer: CVPixelBuffer, texture: MTLTexture, time: TimeInterval) -> CVPixelBuffer? {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
        
        // Reuse render pass descriptor
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        // Ensure viewport matches texture dimensions exactly
        let viewport = CGRect(
            origin: .zero,
            size: CGSize(width: texture.width, height: texture.height)
        )
        
        renderer.render(
            atTime: time,
            viewport: viewport,
            commandBuffer: commandBuffer,
            passDescriptor: renderPassDescriptor
        )

        // Use completion handler instead of blocking wait
        var renderComplete = false
        var renderError: Error?
        
        commandBuffer.addCompletedHandler { commandBuffer in
            if let error = commandBuffer.error {
                renderError = error
            }
            renderComplete = true
        }
        

        commandBuffer.commit()
        
        // Efficient wait with timeout
        let startTime = CACurrentMediaTime()
        while !renderComplete && (CACurrentMediaTime() - startTime) < 0.1 {
            Thread.sleep(forTimeInterval: 0.001)
        }
        
        guard renderComplete, renderError == nil else { return nil }

        // Direct Metal to CVPixelBuffer rendering if possible
        if let metalTextureCache = metalTextureCache {
            return renderDirectToPixelBuffer(buffer: buffer, sourceTexture: texture)
        }
        
        // Fallback to CIImage method
        return renderViaCIImage(buffer: buffer, texture: texture)
    }
    
    private func renderDirectToPixelBuffer(buffer: CVPixelBuffer, sourceTexture: MTLTexture) -> CVPixelBuffer? {
        // Try direct Metal texture to CVPixelBuffer
        guard let metalTextureCache = metalTextureCache else {
            return renderViaCIImage(buffer: buffer, texture: sourceTexture)
        }
        
        var metalTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            metalTextureCache,
            buffer,
            nil,
            .bgra8Unorm,
            CVPixelBufferGetWidth(buffer),
            CVPixelBufferGetHeight(buffer),
            0,
            &metalTexture
        )
        
        guard status == kCVReturnSuccess,
              let metalTex = metalTexture,
              let targetTexture = CVMetalTextureGetTexture(metalTex) else {
            return renderViaCIImage(buffer: buffer, texture: sourceTexture)
        }
        
        // Use Metal to copy and flip
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            return renderViaCIImage(buffer: buffer, texture: sourceTexture)
        }
        
        // Copy with vertical flip - need to handle this properly
        let sourceHeight = sourceTexture.height
        let targetHeight = targetTexture.height
        
        // Copy line by line with flip
        for y in 0..<sourceHeight {
            let sourceY = y
            let targetY = targetHeight - 1 - y
            
            blitEncoder.copy(
                from: sourceTexture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: sourceY, z: 0),
                sourceSize: MTLSize(width: sourceTexture.width, height: 1, depth: 1),
                to: targetTexture,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: targetY, z: 0)
            )
        }
        
        blitEncoder.endEncoding()
        commandBuffer.commit()
        
        return buffer
    }
    
    private func renderViaCIImage(buffer: CVPixelBuffer, texture: MTLTexture) -> CVPixelBuffer? {
        guard let ciImage = CIImage(mtlTexture: texture, options: nil) else {
            return nil
        }

        // Apply pre-computed transform
        let flippedImage = ciImage.transformed(by: flipTransform)
        
        // Minimize lock time
        CVPixelBufferLockBaseAddress(buffer, [])
        ciContext.render(flippedImage, to: buffer)
        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }
    
    // Helper method to validate and fix aspect ratio issues
    private func validateAspectRatio(for sceneView: ARSCNView) {
        let sceneAspectRatio = sceneView.bounds.width / sceneView.bounds.height
        let renderAspectRatio = renderSize.width / renderSize.height
        
        if abs(sceneAspectRatio - renderAspectRatio) > 0.01 {
            print("⚠️ Aspect ratio mismatch detected:")
            print("   Scene: \(sceneAspectRatio) (\(sceneView.bounds.width)x\(sceneView.bounds.height))")
            print("   Render: \(renderAspectRatio) (\(renderSize.width)x\(renderSize.height))")
            print("   This may cause object squeezing/stretching")
        }
    }
    
    // Method to update camera projection when AR session changes
//    func updateCameraProjection(from arFrame: ARFrame) {
//        guard let camera = renderer.pointOfView?.camera else { return }
//        
//        // Update projection matrix to match current AR camera (convert simd to SCNMatrix4)
//        camera.projectionTransform = SCNMatrix4(arFrame.camera.projectionMatrix)
//        
//        // Ensure proper aspect ratio
//        let imageResolution = arFrame.camera.imageResolution
//        let targetAspectRatio = renderSize.width / renderSize.height
//        let cameraAspectRatio = imageResolution.width / imageResolution.height
//        
//        if abs(targetAspectRatio - cameraAspectRatio) > 0.01 {
//            // Adjust camera to maintain proper aspect ratio
//            camera.fieldOfView = camera.fieldOfView * (targetAspectRatio / cameraAspectRatio)
//        }
//    }
//    
    // Clean up resources
    deinit {
        textureCache = nil
        metalTextureCache = nil
    }
}
