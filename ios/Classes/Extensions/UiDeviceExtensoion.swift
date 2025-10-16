//
//  UiDeviceExtensoion.swift
//  Pods
//
//  Created by shreeshant prajapati on 16/10/2025.
//

import UIKit

extension UIDevice {
    /// e.g. "iPhone15,2"
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
    }

    /// Converts model identifier (like "iPhone15,2") into a numeric tuple (15, 2)
    var modelCode: (Int, Int)? {
        let id = modelIdentifier
        let regex = try! NSRegularExpression(pattern: "iPhone(\\d+),(\\d+)")
        if let match = regex.firstMatch(in: id, range: NSRange(location: 0, length: id.utf16.count)),
           let majorRange = Range(match.range(at: 1), in: id),
           let minorRange = Range(match.range(at: 2), in: id),
           let major = Int(id[majorRange]),
           let minor = Int(id[minorRange]) {
            return (major, minor)
        }
        return nil
    }

    /// Returns true if the device is >= iPhone 14 Pro
    var isAtLeastIPhone14Pro: Bool {
        guard let code = modelCode else { return false }
        // iPhone 14 Pro = iPhone15,2
        // So any identifier >= (15,2) should be true
        if code.0 > 15 { return true }       // newer generation
        if code.0 == 15 && code.1 >= 2 { return true } // same generation, higher tier
        return false
    }
}
