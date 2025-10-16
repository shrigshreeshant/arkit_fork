//
//  ARWorldTrackingConfiguration+Extension.swift
//  Pods
//
//  Created by shreeshant prajapati on 16/10/2025.
//

import ARKit

extension ARWorldTrackingConfiguration {
    
    public class func getAppropriateVideoFormat() -> ARConfiguration.VideoFormat? {
        let availableFormats = ARWorldTrackingConfiguration.supportedVideoFormats
        for (index, format) in availableFormats.enumerated() {
            let res = format.imageResolution
            let fps = format.framesPerSecond
            print("""
             [\(index)]
             - Resolution: \(Int(res.width))x\(Int(res.height))
             - FPS: \(fps)
             """)
        }
        if(UIDevice.current.isAtLeastIPhone14Pro) {
            if #available(iOS 16.0, *) {
                if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                    let format = ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution
                    return format
                }
            }
        }
        for format in availableFormats {
            let resolution = format.imageResolution
            if resolution.width / 16 == resolution.height / 9 {
                print("Using video format: \(format)")
                return format
            }
        }
        return nil
    }
}
