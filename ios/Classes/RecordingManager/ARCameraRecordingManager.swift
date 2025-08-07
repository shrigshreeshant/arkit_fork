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
    private var trimmedRgbVideoRecorder: RGBRecorder? = nil
    private let thumbnailGenerator = ThumbnailGenerator()
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
    
    init(sceneview: ARSCNView) {
        super.init()
        self.session = sceneview.session;
        self.sceneView = sceneview;

        sessionQueue.async {
            self.configureSession()
        }

    }
    
    deinit {
        sessionQueue.sync {
            session?.pause()
        }

        
        print("ARCameraRecordingManager deinitialized")
        
    }
    
    

    

    
    // Set up the camera input (LiDAR) for depth data, video, and audio.

    
    // Set up the outputs for video, depth data, and audio.

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
      
        trimmedRgbVideoRecorder = RGBRecorder(videoSettings: videoSettings, queueLabel: "rgb recorder queue trimmed")
        fullRgbVideoRecorder = RGBRecorder(videoSettings: videoSettings, queueLabel: "ful rgb recorder queue")
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
//                r
//
//                
//                // Update live RGB preview stream (e.g., for UI)
                self.rgbStreamer.update(buffer)
                
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
                self.numRgbFrames += 1
                
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
                
                print("**** @Controller: trimmed rgb \(self.numLidarFrames) ****")
                self.trimmedRgbVideoRecorder?.update(buffer, timestamp: timeStamp)
                

                
                
                print("**** @Controller: depth \(self.numLidarFrames) ****")
                self.depthRecorder.update(depthMap)
                
                print("**** @Controller: confidence \(self.numLidarFrames) ****")
                self.confidenceMapRecorder.update(confidenceMap)
                
                print("**** @Controller: camera info \(self.numLidarFrames) ****")
                let cameraInfo = CameraInfo(
                    timestamp: frame.timestamp,
                    intrinsics: frame.camera.intrinsics,
                    transform: frame.camera.transform,
                    eulerAngles: frame.camera.eulerAngles,
                    exposureDuration: frame.camera.exposureDuration
                )
                self.cameraInfoRecorder.update(cameraInfo)
                
                self.numLidarFrames += 1
                
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

        
        guard let sceneView = self.sceneView else {
            print("Error capturing frame")
            return
        }
        if(isArEnabled) {
            let _ = try? sceneView.startVideoRecording(fileType: .mp4)
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
    func stopRecording(completion: RecordingManagerCompletion?,isArEnabled:Bool) {
        
        guard let sceneView=self.sceneView ,let  recoridingId = self.recordingId ,let  dirUrl=self.dirUrl else { return }
        if(isArEnabled){    sceneView.finishVideoRecording { videoRecording in
            let tempURL = videoRecording.url
            let fileName = "\(recoridingId)_AR.mp4"  // You can make this dynamic if needed
            let destinationURL = dirUrl.appendingPathComponent(fileName)
            
            do {
                // Remove if file already exists at destination
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                // Move from temp to app directory
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                print("✅ Video saved to: \(destinationURL)")
            } catch {
                print("❌ Failed to move video file: \(error)")
           } }
        }
        
        guard isRecordingRGBVideo else {
            print("Recording hasn't started yet.")
            return
        }
     
        sessionQueue.async { [weak self] in
            guard let self = self,let sceneView=self.sceneView ,let  recoridingId = self.recordingId else { return }
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
