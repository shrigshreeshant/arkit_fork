//
//  RGBRecorder.swift
//  lidar_camera
//
//  Created by Shrig Solutions on 26/09/2024.
//

import AVFoundation
import Foundation
import Photos

class RGBRecorder: NSObject, Recorder {
    typealias T = CVPixelBuffer

    // AVAssetWriter components for video recording.
    private var assetWriter: AVAssetWriter?
    private var assetWriterVideoInput: AVAssetWriterInput?
    private var assetWriterAudioInput: AVAssetWriterInput?
    private var assetWriterInputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var videoSettings: [String: Any]
    
    private var count: Int32 = 0
    private let rgbRecorderQueue: DispatchQueue
    
    init(videoSettings: [String: Any], queueLabel: String) {
        self.videoSettings = videoSettings
        self.rgbRecorderQueue = DispatchQueue(label: queueLabel)
    }
    
    deinit{
        print("RGBRecorder deinitialized")
    }
    
    func prepareForRecording(dirPath: String, recordingId: String, fileExtension: String = "mp4") {
        rgbRecorderQueue.async {
            self.count = 0
            
            let label = self.rgbRecorderQueue.label
            let suffix = label.contains("trimmed") ? "_trimmed" : ""
            
            let fileName = (recordingId + suffix as NSString).appendingPathExtension(fileExtension)!
            let outputFilePath = (dirPath as NSString).appendingPathComponent(fileName)
            let outputFileUrl = URL(fileURLWithPath: outputFilePath)
            
            guard let assetWriter = try? AVAssetWriter(url: outputFileUrl, fileType: .mp4) else {
                print("Failed to create AVAssetWriter.")
                return
            }
            
            let assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: self.videoSettings)
            
            let assetWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterVideoInput, sourcePixelBufferAttributes: nil)
            
            assetWriterVideoInput.expectsMediaDataInRealTime = true
            assetWriterVideoInput.transform = CGAffineTransform(rotationAngle: .pi / 2)
            
            assetWriter.add(assetWriterVideoInput)
            
            
            // Audio settings.
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 64000
            ]
            let assetAudioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            assetAudioWriterInput.expectsMediaDataInRealTime = true
            assetWriter.add(assetAudioWriterInput)
            
            self.assetWriter = assetWriter
            self.assetWriterVideoInput = assetWriterVideoInput
            self.assetWriterAudioInput = assetAudioWriterInput
            self.assetWriterInputPixelBufferAdaptor = assetWriterInputPixelBufferAdaptor
        }
    }

    
    func update(_ buffer: CVPixelBuffer, timestamp: CMTime?) {
        
        guard let timestamp = timestamp else {
            return
        }
        let label = self.rgbRecorderQueue.label

        rgbRecorderQueue.async {
            
            guard let assetWriter = self.assetWriter else {
                print("Error! assetWriter not initialized.")
                return
            }
            
            print("Saving \(label) video frame \(self.count) ...")
            
            if assetWriter.status == .unknown {
                
                assetWriter.startWriting()
                assetWriter.startSession(atSourceTime: timestamp)
                
                if let adaptor = self.assetWriterInputPixelBufferAdaptor {
                    
                    // incase adaptor not ready
                    // not sure if this is necessary
                    while !adaptor.assetWriterInput.isReadyForMoreMediaData {
                        print("Waiting for assetWriter...")
                        usleep(10)
                    }
                    
                    adaptor.append(buffer, withPresentationTime: timestamp)
                }
                
            } else if assetWriter.status == .writing {
                if let adaptor = self.assetWriterInputPixelBufferAdaptor, adaptor.assetWriterInput.isReadyForMoreMediaData {
                    adaptor.append(buffer, withPresentationTime: timestamp)
                }
            }
            
            self.count += 1
        }
    }
    
    func updateAudioSample(_ buffer: CMSampleBuffer){
        guard let audioWriterInput = assetWriterAudioInput else { return }
        if audioWriterInput.isReadyForMoreMediaData {
            audioWriterInput.append(buffer)
        }
    }
    
    func finishRecording()  {
        
        rgbRecorderQueue.async {
            
            guard let assetWriter = self.assetWriter else {
                print("Error!")
                return
            }
            
            assetWriter.finishWriting { [weak self] in
                guard let self = self else { return }
                
                if let videoURL = self.assetWriter?.outputURL {
                    
                    print("RGB video saved at path: \(videoURL.path)")
                    
                    self.assetWriter = nil
                }
            }
        }
    }
}
