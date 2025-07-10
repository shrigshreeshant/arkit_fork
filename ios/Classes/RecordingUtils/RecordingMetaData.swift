//
//  RecordingMetaData.swift
//  Pods
//
//  Created by Shrig Solutions on 16/12/2024.
//


import Foundation
import UIKit

class DeviceInfo: Codable {
    private var id: String
    private var type: String
    private var name: String
    
    internal init(id: String, type: String, name: String) {
        self.id = id
        self.type = type
        self.name = name
    }
}

class StreamInfo: Encodable {
    private var id: String
    private var encoding: String
    private var frequency: Int
    private var numberOfFrames: Int
    private var fileExtension: String
    
    internal init(id: String, encoding: String, frequency: Int, numberOfFrames: Int, fileExtension: String) {
        self.id = id
        self.encoding = encoding
        self.frequency = frequency
        self.numberOfFrames = numberOfFrames
        self.fileExtension = fileExtension
    }
}

class CameraStreamInfo: StreamInfo {
    private var resolution: [Int]
    private var intrinsics: [Float]?
    
    internal init(id: String, encoding: String, frequency: Int, numberOfFrames: Int, fileExtension: String, resolution: [Int], intrinsics: [Float]?) {
        self.resolution = resolution
        self.intrinsics = intrinsics
        super.init(id: id, encoding: encoding, frequency: frequency, numberOfFrames: numberOfFrames, fileExtension: fileExtension)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(resolution, forKey: .resolution)
        try container.encodeIfPresent(intrinsics, forKey: .intrinsics)
    }
    
    enum CodingKeys: String, CodingKey {
        case resolution
        case intrinsics
        case extrinsics
    }
}

class RecordingMetaData: Encodable {
    
    private var device: DeviceInfo
    private var streams: [StreamInfo]
    
    init(streams: [StreamInfo]) {
        
        let deviceId = UIDevice.current.identifierForVendor?.uuidString
        let modelName = Helper.getDeviceModelCode()
        let deviceName = UIDevice.current.name
        
        device = .init(id: deviceId!, type: modelName, name: deviceName)
        
        self.streams = streams
    }
    
    func writeToFile(filepath: String) {
        try! self.getJsonEncoding().write(toFile: filepath, atomically: true, encoding: .utf8)
    }
    
    func getJsonEncoding() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let data = try! encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}
