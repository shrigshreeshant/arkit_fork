//
//  ARCameraRecordingManager.swift
//  lidar_camera
//
//  Created by Shrig Solutions on 27/09/2024.
//
import ARKit
import CoreLocation
import Flutter

@available(iOS 14.0, *)
class ARCameraRecordingManager: NSObject {
    
    private let sessionQueue = DispatchQueue(label: "ar camera recording queue")
    private let audioRecorderQueue = DispatchQueue(label: "audio recorder queue")
    
    private var session : ARSession? = nil
    private var sceneview : ARSCNView? = nil
    private var renderer: Renderer? = nil
    
    private let depthRecorder = DepthRecorder()
    // both fullRgbVideoRecorders will be initialized in configureSession
    private var fullRgbVideoRecorder: RGBRecorder? = nil
    private var trimmedRgbVideoRecorder: RGBRecorder? = nil
    
    private let cameraInfoRecorder = CameraInfoRecorder()
    private let confidenceMapRecorder = ConfidenceMapRecorder()
    let rgbStreamer: RGBStreamProcessor = RGBStreamProcessor()
    
    private var numRgbFrames: Int = 0
    private var numLidarFrames: Int = 0
    
    private var rgbVideoStartTimeStamp: CMTime = .zero
    private var currentTimeStamp: CMTime = .zero
    private var dirUrl: URL?
    private var recordingId: String?
    var isRecordingRGBVideo: Bool = false
    var isRecordingLidarData: Bool = false
    
    
    private var cameraIntrinsic: simd_float3x3?
    private var colorFrameResolution: [Int] = []
    private var depthFrameResolution: [Int] = []
    private var frequency: Int?
    
    init(session: ARSession,sceneView:ARSCNView) {
        super.init()
        self.session = session;
        self.sceneview=sceneView
        
        let renderSize = CGSize(width: 1920, height: 1440) // or any resolution you want to record

        renderer = Renderer(sceneView: sceneView, size: renderSize)
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
    
    
    // Capture session object to audio input/output.
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
        
        // Enable only scene depth
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }
        
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
        
        let videoSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoHeightKey: NSNumber(value: colorFrameResolution[0]), AVVideoWidthKey: NSNumber(value: colorFrameResolution[1])]
        fullRgbVideoRecorder = RGBRecorder(videoSettings: videoSettings, queueLabel: "rgb recorder queue full")
        trimmedRgbVideoRecorder = RGBRecorder(videoSettings: videoSettings, queueLabel: "rgb recorder queue trimmed")
    }
}

@available(iOS 14.0, *)
extension ARCameraRecordingManager: ARSessionDelegate {

    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
         
         do {
             // Check if renderer is available
             guard let renderer = renderer else {
                 print("⚠️ Renderer not available, skipping frame")
                 return
             }
             
             // Calculate frame time for renderer
             let frameTime = CACurrentMediaTime()
             
             // Render the frame with aspect correction
             guard let buffer = renderer.renderFrame(time: frameTime) else {
                 print("❌ Failed to render frame")
                 return
             }
             
             // Update preview from rendered buffer
             rgbStreamer.update(buffer)
             
             // Only proceed if recording
             guard isRecordingRGBVideo else { return }
             
             let timeStamp = CMTime(seconds: frame.timestamp, preferredTimescale: 1_000_000_000)
             if rgbVideoStartTimeStamp == CMTime.zero {
                 rgbVideoStartTimeStamp = timeStamp
             }
             
             currentTimeStamp = timeStamp
             
             print("**** @Controller: full rgb \(numRgbFrames) ****")
             fullRgbVideoRecorder?.update(buffer, timestamp: timeStamp)
             numRgbFrames += 1
             
             if isRecordingLidarData {
                 
                 // Ensure sceneDepth is available
                 guard let depthData = frame.sceneDepth else {
                     print("Failed to acquire depth data.")
                     return
                 }
                 // Get and copy confidence map
                 guard let confidenceMapOriginal = depthData.confidenceMap else {
                     print("Failed to get confidenceMap.")
                     return
                 }
                 
                 // Copy depth and confidence buffers to avoid retaining shared memory
                 let depthMap = try depthData.depthMap.copy()
                 let confidenceMap = try confidenceMapOriginal.copy()
                 
                 print("**** @Controller: trimmed rgb \(numLidarFrames) ****")
                 trimmedRgbVideoRecorder?.update(buffer, timestamp: timeStamp)
                 
                 print("**** @Controller: depth \(numLidarFrames) ****")
                 depthRecorder.update(depthMap)
                 
                 print("**** @Controller: confidence \(numLidarFrames) ****")
                 confidenceMapRecorder.update(confidenceMap)
                 
                 print("**** @Controller: camera info \(numLidarFrames) ****")
                 let currentCameraInfo = CameraInfo(
                     timestamp: frame.timestamp,
                     intrinsics: frame.camera.intrinsics,
                     transform: frame.camera.transform,
                     eulerAngles: frame.camera.eulerAngles,
                     exposureDuration: frame.camera.exposureDuration
                 )
                 cameraInfoRecorder.update(currentCameraInfo)
                 numLidarFrames += 1
             }
             
         } catch {
             print("Failed to process frame: \(error)")
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
    func startRecording() {
        do {
            try activateAudioSession()
        } catch {
            print("Couldn't activate audio session")
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.numRgbFrames = 0
            self.numLidarFrames = 0
            
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
            
            self.recordingId = Helper.getRecordingId()
            guard let recordingId = self.recordingId else {
                print("Failed to get recording ID")
                return
            }
            self.dirUrl = URL(fileURLWithPath: Helper.getRecordingDataDirectoryPath(recordingId: recordingId))
            guard let dirUrl = self.dirUrl else {
                print("Failed to get recording directory URL")
                return
            }
            
            self.fullRgbVideoRecorder?.prepareForRecording(dirPath: dirUrl.path, recordingId: recordingId)
            self.isRecordingRGBVideo = true
        }
    }
    
    /// Stops the RGB video recording session.
    /// - Deactivates the audio session.
    /// - Stops RGB recording if active.
    /// - If LiDAR data recording is active, finishes those recordings as well.
    /// - Writes metadata file summarizing the recording.
    /// - Executes an optional completion handler with the recording ID.
    func stopRecording(completion: RecordingManagerCompletion?) {
        deactivateAudioSession()
        
        guard isRecordingRGBVideo else {
            print("Recording hasn't started yet.")
            return
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            print("post count: RGB FRAMES\(self.numRgbFrames), LIDAR FRAMES \(self.numLidarFrames)")
            
            self.isRecordingRGBVideo = false
            self.fullRgbVideoRecorder?.finishRecording()
            
            if self.isRecordingLidarData {
                self.stopLidarRecording()
            }
            
            self.writeMetadataToFile()
            completion?(self.recordingId)
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
            self.trimmedRgbVideoRecorder?.prepareForRecording(dirPath: dirUrl.path, recordingId: recordingId)
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
            self.trimmedRgbVideoRecorder?.finishRecording()
            self.depthRecorder.finishRecording()
            self.confidenceMapRecorder.finishRecording()
            self.cameraInfoRecorder.finishRecording()
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
