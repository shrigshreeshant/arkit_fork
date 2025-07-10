//
//  Recorder.swift
//  lidar_camera
//
//  Created by Shrig Solutions on 26/09/2024.
//

import CoreMedia

protocol Recorder {
    associatedtype T
    
    func prepareForRecording(dirPath: String, recordingId: String, fileExtension: String)
    func update(_: T, timestamp: CMTime?)
    func finishRecording()
}
