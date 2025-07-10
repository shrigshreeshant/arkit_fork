//
//  ConfidenceMapRecorder.swift
//  lidar_camera
//
//  Created by Shrig Solutions on 14/12/2024.
//
import Accelerate.vImage
import Compression
import CoreMedia
import CoreVideo
import Foundation

class ConfidenceMapRecorder: Recorder {
    
    typealias T = CVPixelBuffer
    
    private let confidenceMapRecorderQueue = DispatchQueue(label: "confidence map recorder queue")
    
    private var fileHandle: FileHandle? = nil
    private var fileUrl: URL? = nil
    private var compressedFileUrl: URL? = nil
    
    private var count: Int32 = 0
    
    deinit{
        print("ConfidenceMapRecorder deinitialized")
    }
    func prepareForRecording(dirPath: String, recordingId: String, fileExtension: String = "confidence") {
        
        confidenceMapRecorderQueue.async {
            
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
        
        confidenceMapRecorderQueue.async {
            
            print("Saving confidence map \(self.count) ...")
            
            CVPixelBufferLockBaseAddress(buffer, .readOnly)
            
            let baseAddress: UnsafeMutableRawPointer = CVPixelBufferGetBaseAddress(buffer)!
            let size = CVPixelBufferGetDataSize(buffer)
            let data = Data(bytesNoCopy: baseAddress, count: size, deallocator: .none)
            self.fileHandle?.write(data)
            
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
            
            self.count += 1
        }
        
    }
    
    func finishRecording() {
        confidenceMapRecorderQueue.async {
            if self.fileHandle != nil {
                self.fileHandle!.closeFile()
                self.fileHandle = nil
            }
            
            print("\(self.count) confidence maps saved.")
            
            self.compressFile()
            self.removeUncompressedFile()    
        }
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
            print("Uncompressed confidence map file \(fileUrl!.lastPathComponent) removed.")
        } catch {
            print("Unable to remove uncompressed confidence map file.")
        }
    }
    
}
