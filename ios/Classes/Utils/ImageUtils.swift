//
//  ImageUtils.swift
//  Pods
//
//  Created by shreeshant prajapati on 02/09/2025.
//

import CoreImage
import CoreVideo
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

class ImageUtils {
    static let ciContext = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
    ])


    /// Process and crop a CVPixelBuffer (scale, crop).
    static func processPixelBuffer(_ buffer: CVPixelBuffer, desiredAspect: CGFloat = 2556/1179) -> CVPixelBuffer? {
//        return buffer
        autoreleasepool {
            return buffer
            let ciImage = CIImage(cvPixelBuffer: buffer)

            // Original dimensions
            let extent = ciImage.extent
            let originalWidth = extent.width
            let originalHeight = extent.height
            let originalAspect = originalWidth / originalHeight

            print("Original image - Width: \(originalWidth), Height: \(originalHeight)")
            print("Desired aspect: \(desiredAspect)")

            // Compute crop size while preserving desired aspect
            var cropWidth = originalWidth
            var cropHeight = cropWidth / desiredAspect

            if cropHeight > originalHeight {
                // Too tall → shrink width
                cropHeight = originalHeight
                cropWidth = cropHeight * desiredAspect
            }

            let cropRect = CGRect(
                x: (originalWidth - cropWidth) / 2,
                y: (originalHeight - cropHeight) / 2,
                width: cropWidth,
                height: cropHeight
            )
            print("Crop rect - \(cropRect)")

            // Crop
            let cropped = ciImage.cropped(to: cropRect)

            // Normalize to (0,0)
            let normalizeTransform = CGAffineTransform(
                translationX: -cropRect.minX,
                y: -cropRect.minY
            )
            let normalized = cropped.transformed(by: normalizeTransform)

            let outputWidth = Int(cropWidth)
            let outputHeight = Int(cropHeight)
            print("Output size - \(outputWidth)x\(outputHeight)")

            // Create output buffer
            var outputBuffer: CVPixelBuffer?
            let attrs: [CFString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey: outputWidth,
                kCVPixelBufferHeightKey: outputHeight,
                kCVPixelBufferIOSurfacePropertiesKey: [:]
            ]

            let result = CVPixelBufferCreate(
                kCFAllocatorDefault,
                outputWidth,
                outputHeight,
                kCVPixelFormatType_32BGRA,
                attrs as CFDictionary,
                &outputBuffer
            )

            guard result == kCVReturnSuccess, let outBuf = outputBuffer else {
                print("❌ Failed to create pixel buffer: \(result)")
                return nil
            }

            CVPixelBufferLockBaseAddress(outBuf, [])
            defer { CVPixelBufferUnlockBaseAddress(outBuf, []) }

            // Render cropped image into buffer
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
            let renderBounds = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
            ciContext.render(normalized, to: outBuf, bounds: renderBounds, colorSpace: colorSpace)

            print("✅ Successfully processed pixel buffer with aspect ratio crop")
            return outBuf
        }
    }
    /// Process and return JPEG Data instead of pixel buffer
    static func processPixelBufferToJPEG(_ buffer: CVPixelBuffer,
                                         quality: CGFloat = 0.35) -> Data? {
        guard let processed = processPixelBuffer(buffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: processed)
        
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        
        CGImageDestinationAddImage(dest, cgImage, [
            kCGImageDestinationLossyCompressionQuality as String: quality
        ] as CFDictionary)
        
        CGImageDestinationFinalize(dest)
        return data as Data
    }
}


extension ImageUtils {
    static func sizeForAspect(
        baseWidth: Int = 1920,
        baseHeight: Int = 1440,
        aspectRatio: CGFloat
    ) -> (width: Int, height: Int) {
        
        let maxWidth = CGFloat(baseWidth)
        let maxHeight = CGFloat(baseHeight)
        
        print("📐 Base size: \(baseWidth)x\(baseHeight)")
        print("📏 Desired aspect ratio: \(aspectRatio) (w/h)")
        
        // Start by matching base width
        var width = maxWidth
        var height = width / aspectRatio
        print("➡️ Initial size from base width: \(Int(width))x\(Int(height))")
        
        // If too tall, shrink to fit base height
        if height > maxHeight {
            print("⚠️ Height \(height) exceeds maxHeight \(maxHeight), adjusting...")
            height = maxHeight
            width = height * aspectRatio
        }
        
        let finalWidth = Int(width.rounded())
        let finalHeight = Int(height.rounded())
        print("✅ Final size: \(finalWidth)x\(finalHeight)")
        
        return (finalWidth, finalHeight)
    }
}
