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
        let depthBuffer: CVPixelBuffer?
        let confidenceBuffer: CVPixelBuffer?
        let cameraInfo: CameraInfo?
        
    }
    
    private var buffer: [Int: Frame] = [:]
    private let capacity: Int
    private let tag: String
    private var recordedFrameList: Set<Int> = []
    
    init(capacity: Int = 120, tag: String = "[FrameBufferPool]") {
        self.capacity = capacity
        self.tag = tag
        print("\(tag) Initialized with capacity \(capacity)")
    }
    
    func store(frameNumber: Int, pixelBuffer: CVPixelBuffer, timestamp: CMTime,depthBuffer: CVPixelBuffer?,confidenceBuffer: CVPixelBuffer?,cameraInfo: CameraInfo?) {
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
    

    func retrieveFrameList(frameNumber: Int, range: Int = 5) -> [Frame] {
        var result: [Frame] = []

        guard !buffer.isEmpty else {
            print("\(tag) ⚠️ Buffer is empty.")
            return result
        }

        // Calculate start & end safely
        let startIndex = frameNumber-range
        let endIndex = frameNumber+range

        for index in startIndex...endIndex {
            // Skip frames that are already recorded
            guard !recordedFrameList.contains(index) else {
                print("\(tag) ⏭️ Skipping already recorded frame \(index)")
                continue
            }

            if let frame = buffer[index] {
                result.append(frame)
                recordedFrameList.insert(index)  // Mark as recorded
                print("\(tag) ✅ Added frame \(index)")
            } else {
                print("\(tag) ⚠️ Frame \(index) not found.")
            }
        }

        print("\(tag) 📦 Retrieved \(result.count) new frames (\(startIndex)...\(endIndex))")
        return result
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
