//
//  ARCameraRecordingManager.swift
//  lidar_camera
//
//  Created by Shrig Solutions on 27/09/2024.
//
import ARKit
import CoreLocation
import Flutter
import SCNRecorder


import UIKit

struct DevicePixels {
    static var size: CGSize {
        let bounds = UIScreen.main.bounds      // logical points
        let scale = UIScreen.main.scale        // pixel density
        return CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
    }

    static var width: CGFloat { size.width }
    static var height: CGFloat { size.height }
}

@available(iOS 14.0, *)
class ARCameraRecordingManager: NSObject {
    
    private let sessionQueue = DispatchQueue(label: "ar camera recording queue")
    private let audioRecorderQueue = DispatchQueue(label: "audio recorder queue")
    private var thumbnailPath: String? = nil
    private var session : ARSession? = nil
    private var count: Int = 0
    private var sceneView: ARSCNView? = nil

    
    private let depthRecorder = DepthRecorder()
    // both fullRgbVideoRecorders will be initialized in configureSession
    private var fullRgbVideoRecorder: RGBRecorder? = nil
    private var goodWindowRgbVIdeoRecorder: RGBRecorder? = nil
    private let thumbnailGenerator = ThumbnailGenerator()
    private let cameraInfoRecorder = CameraInfoRecorder()
    private let confidenceMapRecorder = ConfidenceMapRecorder()
    let rgbStreamer: RGBStreamProcessor = RGBStreamProcessor()
    
    
    //frame buffer pool
    private let frameBufferPool = FrameBufferPool(capacity:60)
    private var numRgbFrames: Int = 0
    private var totalNoOfRgbFrame: Int = 0
    private var numLidarFrames: Int = 0
    
    private var rgbVideoStartTimeStamp: CMTime = .zero
    private var currentTimeStamp: CMTime = .zero
    private var dirUrl: URL?
    private var recordingId: String?
    var isRecordingRGBVideo: Bool = false
    var isRecordingLidarData: Bool = false
    private var arEnableDuringRecording: Bool = false
  
    private var cameraIntrinsic: simd_float3x3?
    private var colorFrameResolution: [Int] = []
    private var depthFrameResolution: [Int] = []
    private var frequency: Int?
    
    
    
    
    init(sceneview: ARSCNView) {
        super.init()
        self.session = sceneview.session;
        self.sceneView = sceneview;

        sessionQueue.async {
            self.configureSession()
        }
        audioRecorderQueue.async {
            self.setupAudioSession()
        }

    }
    
    deinit {
        sessionQueue.sync {
            session?.pause()
        }
        audioRecorderQueue.sync {
            deactivateAudioSession()
        }

        
        print("ARCameraRecordingManager deinitialized")
        
    }
    
    

    

    
    // Set up the camera input (LiDAR) for depth data, video, and audio.
    func setArEnableDuringRecording(_ enabled: Bool) {
       

        if isRecordingRGBVideo {
            if self.arEnableDuringRecording != true {
                
                self.arEnableDuringRecording = enabled
            }
        }
    }
    
    // Set up the outputs for video, depth data, and audio.
    private(set) var audioCaptureSession: AVCaptureSession?
    // Output for audio
    private var audioDataOutput: AVCaptureAudioDataOutput?
    
    // Set up the capture session with audio inputs and outputs.
    private func setupAudioSession() {
        do {
            audioCaptureSession = AVCaptureSession()
            guard let audioCaptureSession = audioCaptureSession else {
                throw ConfigurationError.sessionUnavailable
            }
            audioCaptureSession.automaticallyConfiguresApplicationAudioSession = false
            audioCaptureSession.beginConfiguration()
            try setupAudioCaptureInput()
            try setupAudioCaptureOutput()
            audioCaptureSession.commitConfiguration()
        } catch {
            print("Unable to configure the audio session.")
        }
    }
    
    // Set up the camera input (LiDAR) for depth data, video, and audio.
    private func setupAudioCaptureInput() throws {
        guard let audioCaptureSession = audioCaptureSession else {
            throw ConfigurationError.sessionUnavailable
        }
        
        // Set up audio input (microphone)
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw ConfigurationError.micUnavailable
        }
        
        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
        audioCaptureSession.addInput(audioInput)  // Add the audio input to the capture session.
    }
    
    // Set up the outputs for video, depth data, and audio.
    private func setupAudioCaptureOutput() throws{
        guard let audioCaptureSession = audioCaptureSession else {
            throw ConfigurationError.sessionUnavailable
        }
        
        // Configure the audio data output.
        audioDataOutput = AVCaptureAudioDataOutput()
        guard let audioDataOutput = audioDataOutput else {return}
        audioDataOutput.setSampleBufferDelegate(self, queue: audioRecorderQueue)
        audioCaptureSession.addOutput(audioDataOutput)
        
    }

    private func find4by3VideoFormat() -> ARConfiguration.VideoFormat? {
        let availableFormats = ARWorldTrackingConfiguration.supportedVideoFormats
        if #available(iOS 16.0, *) {
            let format = ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution
            let resolution = format?.imageResolution
            let fps = format?.framesPerSecond
            guard let resolution = resolution else{ return nil}
            print("✅ Recommended 4K format: \(Int(resolution.width))x\(Int(resolution.height)) @ \(fps) FPS")
            return format
        }
        for format in availableFormats {
            let resolution = format.imageResolution
            if resolution.width / 4 == resolution.height / 3 {
                print("Using video format: \(format)")
                return format
            }
        }
        return nil
    }
    
    
    
    
    
       private func configureSession() {
        
        let configuration = ARWorldTrackingConfiguration()
        

        // Optionally, set the video format if available
        if let format = find4by3VideoFormat() {
            configuration.videoFormat = format
        } else {
            print("No 4:3 video format is available")
        }
        
        // Set session delegate and run the session
        session?.delegate = self
        
        let videoFormat = configuration.videoFormat
        frequency = videoFormat.framesPerSecond
        let imageResolution = videoFormat.imageResolution
        colorFrameResolution = [Int(imageResolution.height), Int(imageResolution.width)]
        
        print("✅ Recommended Color frame 4K format: \(Int(colorFrameResolution[0]))x\(Int(colorFrameResolution[1])) ")
        
        guard self.sceneView != nil else { return }
      


        
        let videoSettings: [String: Any] =  [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoHeightKey: NSNumber(value:colorFrameResolution[0]), AVVideoWidthKey: NSNumber(value: colorFrameResolution[1])]
        
        let goodWindoVideoSetting: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoHeightKey: NSNumber(value:colorFrameResolution[0]), AVVideoWidthKey: NSNumber(value: colorFrameResolution[1])]
      
        fullRgbVideoRecorder = RGBRecorder(videoSettings: videoSettings, queueLabel: "ful rgb recorder queue")
        
        goodWindowRgbVIdeoRecorder = RGBRecorder(videoSettings: goodWindoVideoSetting, queueLabel: "good window rgb recorder queue")
    }
}
private let renderQueue = DispatchQueue(label: "com.myapp.rgbRenderQueue", qos: .userInitiated)

@available(iOS 14.0, *)
extension ARCameraRecordingManager: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        renderQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let buffer = try frame.capturedImage.copy()

                let width = CVPixelBufferGetWidth(buffer)
                let height = CVPixelBufferGetHeight(buffer)

                print("PixelBuffer dimensions: \(width)x\(height)")
//
//                
//                // Update live RGB preview stream (e.g., for UI)
         
                
                // Skip video processing if not recording
                guard self.isRecordingRGBVideo else { return }
                
         
                
                // Convert AR timestamp to CMTime for video writing
                let timeStamp = CMTime(seconds: frame.timestamp, preferredTimescale: 1_000_000_000)
                
                if self.rgbVideoStartTimeStamp == .zero {
                    self.rgbVideoStartTimeStamp = timeStamp
                }
//                
                self.currentTimeStamp = timeStamp
                
                print("**** @Controller: full rgb \(self.numRgbFrames) ****")
                self.fullRgbVideoRecorder?.update(buffer, timestamp: timeStamp)
         
      
                // Depth + Confidence + Camera Info recording
                guard self.isRecordingLidarData else { return }
                
                guard let depthData = frame.sceneDepth else {
                    print("❌ Failed to acquire depth data.")
                    return
                }
                
                guard let confidenceMapOriginal = depthData.confidenceMap else {
                    print("❌ Failed to get confidenceMap.")
                    return
                }
                
                // Copy buffers to avoid retaining shared memory
                let depthMap = try depthData.depthMap.copy()
                let confidenceMap = try confidenceMapOriginal.copy()
    

                
                print("**** @Controller: depth \(self.numLidarFrames) ****")
//                self.depthRecorder.update(depthMap)
                
                print("**** @Controller: confidence \(self.numLidarFrames) ****")
//                self.confidenceMapRecorder.update(confidenceMap)
                
                print("**** @Controller: camera info \(self.numLidarFrames) ****")
                let cameraInfo = CameraInfo(
                    timestamp: frame.timestamp,
                    intrinsics: frame.camera.intrinsics,
                    transform: frame.camera.transform,
                    eulerAngles: frame.camera.eulerAngles,
                    exposureDuration: frame.camera.exposureDuration
                )
                
                
                frameBufferPool.store(frameNumber: self.totalNoOfRgbFrame, pixelBuffer: buffer, timestamp: currentTimeStamp,depthBuffer: depthMap,confidenceBuffer: confidenceMap,cameraInfo:cameraInfo)
                self.cameraInfoRecorder.update(cameraInfo)
                self.rgbStreamer.update(buffer,self.totalNoOfRgbFrame,self.currentTimeStamp)
                self.totalNoOfRgbFrame += 1
     
                
            } catch {
                print("❌ Failed to process frame: \(error)")
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("ARSession failed with error: \(error.localizedDescription)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("⚠️ AR Session interrupted")
    }
}




@available(iOS 14.0, *)
extension ARCameraRecordingManager {
    
    /// Helper to safely unwrap the current recording ID and directory URL.
    /// Returns a tuple (recordingId, dirUrl) or nil if unavailable.
    private func recordingResources() -> (recordingId: String, dirUrl: URL)? {
        guard let recordingId = recordingId,
              let dirUrl = dirUrl else {
            print("Recording resources unavailable")
            return nil
        }
        return (recordingId, dirUrl)
    }
    
    /// Starts the RGB video recording session.
    /// - Activates the audio session.
    /// - Initializes frame count and recording ID.
    /// - Prepares the RGB video recorder for recording in the appropriate directory.
    /// - Runs asynchronously on the session queue.
    func startRecording(isArEnabled:Bool) {

        do {
            try activateAudioSession()
        } catch {
            print("Couldn't activate audio session")
        }
        
        guard let sceneView = self.sceneView else {
            print("Error capturing frame")
            return
        }
        self.recordingId = Helper.getRecordingId()
        guard let recordingId = self.recordingId else {
            print("Failed to get recording ID")
            return
        }
        self.dirUrl = URL(fileURLWithPath: Helper.getRecordingDataDirectoryPath(recordingId: recordingId))
            let _ = try? sceneView.startVideoRecording(fileType: .mp4)
                 sessionQueue.async { [weak self] in
                guard let self = self else { return }
                self.numRgbFrames = 0
                self.numLidarFrames = 0
                     self.numLidarFrames=0
     
                
                self.rgbVideoStartTimeStamp = .zero
                if let currentFrame = session?.currentFrame {

                    cameraIntrinsic = currentFrame.camera.intrinsics
                    if let depthData = currentFrame.sceneDepth {
                        
                        let depthMap: CVPixelBuffer = depthData.depthMap
                        let height = CVPixelBufferGetHeight(depthMap)
                        let width = CVPixelBufferGetWidth(depthMap)
                        
                        depthFrameResolution = [height, width]
                    } else {
                        print("Unable to get depth resolution.")
                    }
                }
            
                print("pre count: RGB FRAMES \(self.numRgbFrames), LIDAR FRAMES \(self.numRgbFrames)")
                
         
          
          
                guard let dirUrl = self.dirUrl else {
                         print("Failed to get recording directory URL")
                         return
                     }
                     
                self.fullRgbVideoRecorder?.prepareForRecording(dirPath: dirUrl.path, recordingId: recordingId)
                     self.goodWindowRgbVIdeoRecorder?.prepareForRecording(dirPath: dirUrl.path, recordingId: recordingId,suffix: "_goodWindow")
      


            }
        
        self.isRecordingRGBVideo = true
        startLidarRecording()

        setArEnableDuringRecording(isArEnabled)
        }
    
    /// Stops the RGB video recording session.
    /// - Deactivates the audio session.
    /// - Stops RGB recording if active.
    /// - If LiDAR data recording is active, finishes those recordings as well.
    /// - Writes metadata file summarizing the recording.
    /// - Executes an optional completion handler with the recording ID.
    func stopRecording(completion: RecordingManagerCompletion?, isArEnabled: Bool) {

        deactivateAudioSession()
        guard let sceneView = self.sceneView,
              let recordingId = self.recordingId,
              let dirUrl = self.dirUrl else {
            return
        }

        guard isRecordingRGBVideo else {
            print("Recording hasn't started yet.")
            completion?(recordingId)
            return
        }

        // Mark RGB recording as stopped
        self.isRecordingRGBVideo = false

        // URLs for final videos
        let rgbVideoURL = dirUrl.appendingPathComponent("\(recordingId)_regular.mp4")
        let arVideoURL = dirUrl.appendingPathComponent("\(recordingId)_ar.mp4")

//
        let group = DispatchGroup()
//

        group.enter()
        sceneView.finishVideoRecording { videoRecording in
            defer { group.leave() }
            do {
                let destinationURL = arVideoURL
                let tempURL = videoRecording.url

                if FileManager.default.fileExists(atPath: arVideoURL.path) {
                    try FileManager.default.removeItem(at: arVideoURL)
                }

                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                print("✅ AR Video saved: \(arVideoURL)")
            } catch {
                print("❌ Failed to move AR video file: \(error)")
            }
        }

        group.enter()
        fullRgbVideoRecorder?.finishRecording { [weak self] in
            defer { group.leave() }
            
            guard let self = self else { return }


            print("✅ RGB Video finished: \(rgbVideoURL)")

   
        }
        
        group.enter()
        goodWindowRgbVIdeoRecorder?.finishRecording { [weak self] in
            defer { group.leave() }
            
            guard let self = self else { return }
            self.frameBufferPool.clear()

            print("✅ goodWindow Video finished")

        }
        if self.isRecordingLidarData {
            self.stopLidarRecording()
        }

        group.notify(queue: .main) {
            print("🎉 Both AR and RGB recordings are finished")
            self.writeMetadataToFile()
            self.finalizeRecording(arVideoURL: arVideoURL, rgbVideoURL: rgbVideoURL, recordingId: recordingId, completion:completion )
        }
       
    }

    
    private func finalizeRecording(
        arVideoURL: URL,
        rgbVideoURL: URL,
        recordingId: String?,
        completion: ((String?) -> Void)?
    ) {
        do {
            let rgbExists = FileManager.default.fileExists(atPath: rgbVideoURL.path)
            let arExists = FileManager.default.fileExists(atPath: arVideoURL.path)
            guard  rgbExists && arExists else {
                print("⚠️ finalizeRecording: Some video path does not exist: RGB: \(rgbExists) AR: \(arExists)")
                completion?(nil)
                return
            }
            
            print("🔹 rEnabledudio: \(arEnableDuringRecording)")
            
            if(arEnableDuringRecording){
                arEnableDuringRecording=false
                completion?(recordingId)
//                print("🔹 Starting RGB video update with AR audio")
//                let audioUtils = AudioUtils()
//                audioUtils.updateRGBVideoWithAudio(from: arVideoURL, rgbVideoURL: rgbVideoURL) { result in
//                    DispatchQueue.main.async {
//                        switch result {
//                        case .success(let updatedURL):
//                            print("✅ RGB video updated with AR audio: \(updatedURL)")
//                            completion?(recordingId)
//
//                        case .failure(let error):
//                            print("❌ Audio update failed: \(error)")
//                            completion?(nil)
//
//                        }
//                    }
//                }
            } else{
                try FileManager.default.removeItem(at: arVideoURL)
//                try FileManager.default.moveItem(at: arVideoURL, to: rgbVideoURL)
                print("✅ finalizeRecording: Deleted old Ar video at \(arVideoURL.lastPathComponent) and moved Rgb to \(rgbVideoURL.lastPathComponent)")
                completion?(recordingId)

            }
         
        } catch {
            print("❌ finalizeRecording: Error while deleting/renaming video: \(error.localizedDescription)")
            completion?(nil)
        }
    }
    
    /// Starts LiDAR depth data recording.
    /// - Requires RGB recording to be active.
    /// - Prepares depth, confidence map, and camera info recorders.
    /// - Marks LiDAR data recording as active.
    /// - Calls the provided completion closure with the current frame timestamp if available, else nil.
    func startLidarRecording(completion: DepthDataStartCompletion? = nil) {
        guard isRecordingRGBVideo else {
            print("Recording session hasn't started yet.")
            return
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let (recordingId, dirUrl) = self.recordingResources() else {
                return
            }
            self.depthRecorder.prepareForRecording(dirPath: dirUrl.path, recordingId: recordingId)
            self.confidenceMapRecorder.prepareForRecording(dirPath: dirUrl.path, recordingId: recordingId)
            self.cameraInfoRecorder.prepareForRecording(dirPath: dirUrl.path, recordingId: recordingId)
            self.isRecordingLidarData = true
            
            // 🔹 Compute offset relative to RGB start
            let offset = CMTimeSubtract(self.currentTimeStamp, self.rgbVideoStartTimeStamp)
            let offsetMillis = Int((Double(offset.value) / Double(offset.timescale)) * 1000)
            completion?(offsetMillis)
        }
    }
    
    
    func recordGoodFrame(_ frameParams: [String:Any]){
        
        if let frameNumber = frameParams["frameNumber"] as? Int {
            guard let frame = frameBufferPool.retrieve(frameNumber: frameNumber) else{
    
                return
            }
            frameBufferPool.remove(frameNumber: frameNumber)
            self.goodWindowRgbVIdeoRecorder?.update(frame.pixelBuffer, timestamp: frame.timestamp)
            self.depthRecorder.update(frame.depthBuffer, timestamp: frame.timestamp)
            self.confidenceMapRecorder.update(frame.confidenceBuffer, timestamp: frame.timestamp)
            self.cameraInfoRecorder.update(frame.cameraInfo, timestamp: frame.timestamp)
            self.numRgbFrames+=1
            self.numLidarFrames+=1
            
        } else {  
            print("⚠️ frameNumber is missing or not an Int")
        }
        

        
    }
    
    /// Stops LiDAR depth data recording.
    /// - Finishes all LiDAR-related recordings if active.
    /// - Sets the LiDAR recording flag to false.
    func stopLidarRecording() {
        guard isRecordingLidarData else {
            print("Lidar data Recording hasn't started yet.")
            return
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.isRecordingLidarData = false
            self.depthRecorder.finishRecording()
            self.confidenceMapRecorder.finishRecording()
            self.cameraInfoRecorder.finishRecording()
            writeMetadataToFile()
        }
    }
    
    /// Writes recording metadata to a JSON file.
    /// - Includes stream info for RGB video, LiDAR depth map, confidence map, and camera info.
    /// - Metadata file is saved inside the recording directory.
    private func writeMetadataToFile() {
        guard let (recordingId, dirUrl) = recordingResources() else { return }
        
        let intrinsicArray = cameraIntrinsic?.arrayRepresentation
        let frequencyValue = frequency ?? 0
        
        let streams: [StreamInfo] = [
            CameraStreamInfo(id: "full_rgb_video", encoding: "h264", frequency: frequencyValue, numberOfFrames: numRgbFrames, fileExtension: "mp4", resolution: colorFrameResolution, intrinsics: intrinsicArray),
            CameraStreamInfo(id: "rgb_video", encoding: "h264", frequency: frequencyValue, numberOfFrames: numLidarFrames, fileExtension: "mp4", resolution: colorFrameResolution, intrinsics: intrinsicArray),
            CameraStreamInfo(id: "lidar_depth_map", encoding: "float16_zlib", frequency: frequencyValue, numberOfFrames: numLidarFrames, fileExtension: "depth.zlib", resolution: depthFrameResolution, intrinsics: nil),
            StreamInfo(id: "confidence_map", encoding: "uint8_zlib", frequency: frequencyValue, numberOfFrames: numLidarFrames, fileExtension: "confidence.zlib"),
            StreamInfo(id: "camera_info", encoding: "jsonl", frequency: frequencyValue, numberOfFrames: numLidarFrames, fileExtension: "jsonl")
        ]
        
        let metadata = RecordingMetaData(streams: streams)
        
        let metadataPath = dirUrl.appendingPathComponent(recordingId).appendingPathExtension("json").path
        metadata.writeToFile(filepath: metadataPath)
    }
}



@available(iOS 14.0, *)
extension ARCameraRecordingManager: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !isRecordingRGBVideo {
            return
        }
        if output == audioDataOutput {
            fullRgbVideoRecorder?.updateAudioSample(sampleBuffer)
        }
    }
    
    func activateAudioSession() throws {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord,
                                         mode: .videoRecording,
                                         options: [.mixWithOthers,
                                                   .allowBluetoothA2DP,
                                                   .defaultToSpeaker,
                                                   .allowAirPlay])
            
            if #available(iOS 14.5, *) {
                // prevents the audio session from being interrupted by a phone call
                try audioSession.setPrefersNoInterruptionsFromSystemAlerts(true)
            }
            

            // allow system sounds (notifications, calls, music) to play while recording
            try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
            audioRecorderQueue.async {
                self.audioCaptureSession?.startRunning()
            }
        } catch let error as NSError {
            switch error.code {
            case 561_017_449:
                throw ConfigurationError.micInUse
            default:
                throw ConfigurationError.audioSessionFailedToActivate
            }
        }
    }
    
    func deactivateAudioSession() {
        guard let audioCaptureSession = audioCaptureSession else {
            return
        }
        if(audioCaptureSession.isRunning){
            audioCaptureSession.stopRunning()
        }
    }
}
