//
//  DepthRecorder.swift
//  lidar_camera
//
//  Created by Shrig Solutions on 26/09/2024.
//

import Accelerate.vImage
import Compression
import CoreMedia
import CoreVideo
import Foundation

class DepthRecorder: Recorder {
    
    typealias T = CVPixelBuffer
    
    private let depthRecorderQueue = DispatchQueue(label: "depth recorder queue")
    
    private var count: Int32 = 0
    private var fileHandle: FileHandle? = nil
    private var fileUrl: URL? = nil
    private var compressedFileUrl: URL? = nil
    deinit{
        print("DepthRecorder deinitialized")
    }
    func prepareForRecording(dirPath: String, recordingId: String, fileExtension: String = "depth") {
        
        depthRecorderQueue.async {
            
            self.count = 0
            
            let filePath = (dirPath as NSString).appendingPathComponent((recordingId as NSString).appendingPathExtension(fileExtension)!)
            let compressedFilePath = (filePath as NSString).appendingPathExtension("zlib")!
            self.fileUrl = URL(fileURLWithPath: filePath)
            self.compressedFileUrl = URL(fileURLWithPath: compressedFilePath)
            FileManager.default.createFile(atPath: self.fileUrl!.path, contents: nil, attributes: nil)
            
            self.fileHandle = FileHandle(forUpdatingAtPath: self.fileUrl!.path)
            if self.fileHandle == nil {
                print("Unable to create file handle.")
                return
            }
        }
        
    }
    
    func update(_ buffer: CVPixelBuffer, timestamp: CMTime? = nil) {
        depthRecorderQueue.async {
            print("Saving depth frame \(self.count) ...")
            self.convertF32DepthMapToF16AndWriteToFile(f32CVPixelBuffer: buffer)
            self.count += 1
        }
    }
    
    func finishRecording() {
        depthRecorderQueue.async {
            if self.fileHandle != nil {
                self.fileHandle!.closeFile()
                self.fileHandle = nil
            }
            print("\(self.count) frames of depth saved.")
            self.compressFile()
            self.removeUncompressedFile()
            
        }
    }
    
    private func convertF32DepthMapToF16AndWriteToFile(f32CVPixelBuffer: CVPixelBuffer) {
        
        CVPixelBufferLockBaseAddress(f32CVPixelBuffer, .readOnly)
        
        let height = CVPixelBufferGetHeight(f32CVPixelBuffer)
        let width = CVPixelBufferGetWidth(f32CVPixelBuffer)
        let numPixel = height * width
        
        var f32vImageBuffer = vImage_Buffer()
        f32vImageBuffer.data = CVPixelBufferGetBaseAddress(f32CVPixelBuffer)!
        f32vImageBuffer.height = UInt(height)
        f32vImageBuffer.width = UInt(width)
        f32vImageBuffer.rowBytes = CVPixelBufferGetBytesPerRow(f32CVPixelBuffer)
        
        var error = kvImageNoError
        
        var f16vImageBuffer = vImage_Buffer()
        error = vImageBuffer_Init(&f16vImageBuffer,
                                  f32vImageBuffer.height,
                                  f32vImageBuffer.width,
                                  16,
                                  vImage_Flags(kvImageNoFlags))
        
        guard error == kvImageNoError else {
            print("Unable to init destination vImagebuffer.")
            return
        }
        defer {
            free(f16vImageBuffer.data)
        }
        
        error = vImageConvert_PlanarFtoPlanar16F(&f32vImageBuffer,
                                                 &f16vImageBuffer,
                                                 vImage_Flags(kvImagePrintDiagnosticsToConsole))
        
        guard error == kvImageNoError else {
            print("Unable to convert.")
            return
        }
        
        self.fileHandle?.write(Data(bytesNoCopy: f16vImageBuffer.data, count: numPixel * 2, deallocator: .none))
        
        CVPixelBufferUnlockBaseAddress(f32CVPixelBuffer, .readOnly)
    }
    
    
    private func compressFile() {
        guard let fileUrl = fileUrl,let compressedFileUrl = compressedFileUrl else{
            return
        }
        
        let algorithm = COMPRESSION_ZLIB
        let operation = COMPRESSION_STREAM_ENCODE
        
        FileManager.default.createFile(atPath: compressedFileUrl.path, contents: nil, attributes: nil)
        
        if let sourceFileHandle = try? FileHandle(forReadingFrom: fileUrl),
           let destinationFileHandle = try? FileHandle(forWritingTo: compressedFileUrl) {
            
            Compressor.streamingCompression(operation: operation,
                                            sourceFileHandle: sourceFileHandle,
                                            destinationFileHandle: destinationFileHandle,
                                            algorithm: algorithm) {_ in 
            }
        }
    }
    
    private func removeUncompressedFile() {
        do {
            try FileManager.default.removeItem(at: fileUrl!)
            print("Uncompressed depth file \(fileUrl!.lastPathComponent) removed.")
        } catch {
            print("Unable to remove uncompressed depth file.")
        }
    }
}
