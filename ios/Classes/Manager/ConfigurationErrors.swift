//
//  ConfigurationErrors.swift
//  lidar_camera
//
//  Created by Shrig Solutions on 19/09/2024.
//

import Foundation
enum ConfigurationError: Error {
    case sessionUnavailable
    case requiredFormatUnavailable
    case micUnavailable
    case micInUse
    case audioSessionFailedToActivate
}
