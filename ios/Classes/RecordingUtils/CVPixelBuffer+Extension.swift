//
//  CopyError.swift
//  Pods
//
//  Created by Shrig0001 on 26/05/2025.
//


public extension CVPixelBuffer {

    enum CopyError: Error {
        case allocationFailed
    }

    func copy() throws -> CVPixelBuffer {
        precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() can only be called on CVPixelBuffer")

        var _copy: CVPixelBuffer?
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let formatType = CVPixelBufferGetPixelFormatType(self)
        let attachments = CVBufferCopyAttachments(self, .shouldPropagate)

        let status = CVPixelBufferCreate(nil, width, height, formatType, attachments, &_copy)

        guard status == kCVReturnSuccess, let copy = _copy else {
            throw CopyError.allocationFailed
        }

        CVPixelBufferLockBaseAddress(self, .readOnly)
        CVPixelBufferLockBaseAddress(copy, [])

        defer {
            CVPixelBufferUnlockBaseAddress(copy, [])
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
        }

        let planeCount = CVPixelBufferGetPlaneCount(self)

        if planeCount == 0 {
            // Non-planar
            let src = CVPixelBufferGetBaseAddress(self)
            let dst = CVPixelBufferGetBaseAddress(copy)
            let height = CVPixelBufferGetHeight(self)
            let bytesPerRowSrc = CVPixelBufferGetBytesPerRow(self)
            let bytesPerRowDst = CVPixelBufferGetBytesPerRow(copy)

            for row in 0..<height {
                let srcRow = src?.advanced(by: row * bytesPerRowSrc)
                let dstRow = dst?.advanced(by: row * bytesPerRowDst)
                memcpy(dstRow, srcRow, min(bytesPerRowSrc, bytesPerRowDst))
            }
        } else {
            // Planar
            for plane in 0..<planeCount {
                let src = CVPixelBufferGetBaseAddressOfPlane(self, plane)
                let dst = CVPixelBufferGetBaseAddressOfPlane(copy, plane)
                let height = CVPixelBufferGetHeightOfPlane(self, plane)
                let bytesPerRowSrc = CVPixelBufferGetBytesPerRowOfPlane(self, plane)
                let bytesPerRowDst = CVPixelBufferGetBytesPerRowOfPlane(copy, plane)

                for row in 0..<height {
                    let srcRow = src?.advanced(by: row * bytesPerRowSrc)
                    let dstRow = dst?.advanced(by: row * bytesPerRowDst)
                    memcpy(dstRow, srcRow, min(bytesPerRowSrc, bytesPerRowDst))
                }
            }
        }

        return copy
    }
}
