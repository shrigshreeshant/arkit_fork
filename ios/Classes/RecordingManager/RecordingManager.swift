//
//  RecordingManager.swift
//  lidar_camera
//
//  Created by Shrig Solutions on 26/09/2024.
//

import Foundation
import AVFoundation

typealias RecordingManagerCompletion = (String?) -> Void
typealias DepthDataStartCompletion = (Int?) -> Void

protocol RecordingManager {
    var isRecording: Bool { get }
    
    func getSession() -> NSObject
    
    func startRecording()
    func stopRecording(completion: RecordingManagerCompletion?)
}
