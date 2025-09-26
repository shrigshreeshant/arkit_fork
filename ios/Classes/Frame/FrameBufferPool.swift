//
//  FrameBufferPool.swift
//  Pods
//
//  Created by shreeshant prajapati on 25/09/2025.
//

class FrameBufferPool {
    struct Frame {
        let number: Int
        let pixelBuffer: CVPixelBuffer
        let timestamp: CMTime
        let depthBuffer: CVPixelBuffer
        let confidenceBuffer: CVPixelBuffer
        let cameraInfo: CameraInfo
        
    }
    
    private var buffer: [Int: Frame] = [:]
    private let capacity: Int
    private let tag: String
    
    init(capacity: Int = 120, tag: String = "[FrameBufferPool]") {
        self.capacity = capacity
        self.tag = tag
        print("\(tag) Initialized with capacity \(capacity)")
    }
    
    func store(frameNumber: Int, pixelBuffer: CVPixelBuffer, timestamp: CMTime,depthBuffer: CVPixelBuffer,confidenceBuffer: CVPixelBuffer,cameraInfo: CameraInfo) {
        buffer[frameNumber] = Frame(number: frameNumber, pixelBuffer: pixelBuffer, timestamp: timestamp,depthBuffer: depthBuffer,confidenceBuffer: confidenceBuffer,cameraInfo: cameraInfo)
        print("\(tag) Stored frame \(frameNumber). Current count: \(buffer.count)")
        
        // prune oldest if buffer is too big
        if buffer.count > capacity {
            if let oldest = buffer.keys.min() {
                buffer.removeValue(forKey: oldest)
                print("\(tag) Pruned oldest frame \(oldest). Count after prune: \(buffer.count)")
            }
        }
    }
    
    func retrieve(frameNumber: Int) -> Frame? {
        let frame = buffer[frameNumber]
        if frame != nil {
            print("\(tag) Retrieved frame \(frameNumber)")
        } else {
            print("\(tag) Frame \(frameNumber) not found")
        }
        return frame
    }
    
    func remove(frameNumber: Int) {
        if buffer.removeValue(forKey: frameNumber) != nil {
            print("\(tag) Removed frame \(frameNumber). Current count: \(buffer.count)")
        } else {
            print("\(tag) Tried to remove missing frame \(frameNumber)")
        }
    }
    
    func clear() {
           let count = buffer.count
           buffer.removeAll()
           print("\(tag) Cleared all frames. Removed \(count) frames")
       }
}
