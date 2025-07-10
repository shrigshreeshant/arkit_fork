//
//  Helper.swift
//  lidar_camera
//
//  Created by Shrig Solutions on 26/09/2024.
//
import Foundation
import UIKit

struct Helper {
    
    static func getRecordingId() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmssZ"
        let dateString = dateFormatter.string(from: Date())
        
        let recordingId = dateString + "_" + UUID().uuidString
        
        return recordingId
    }
    
    static func getRecordingDataDirectoryPath(recordingId: String) -> String {
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        
        // create new directory for new recording
        let documentsDirectoryUrl = URL(string: documentsDirectory)!
        let recordingDataDirectoryUrl = documentsDirectoryUrl.appendingPathComponent(recordingId)
        if !FileManager.default.fileExists(atPath: recordingDataDirectoryUrl.absoluteString) {
            do {
                try FileManager.default.createDirectory(atPath: recordingDataDirectoryUrl.absoluteString, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription);
            }
        }
        
        let recordingDataDirectoryPath = recordingDataDirectoryUrl.absoluteString
        return recordingDataDirectoryPath
    }
    
    static func getDeviceModelCode() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}
