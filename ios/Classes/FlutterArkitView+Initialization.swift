import ARKit


extension SCNVector3 {
    func length() -> Float {
        return sqrt(x*x + y*y + z*z)
    }

    func normalized() -> SCNVector3 {
        let len = length()
        return len > 0 ? self / len : SCNVector3(0,0,0)
    }

    func cross(vector: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            x: y * vector.z - z * vector.y,
            y: z * vector.x - x * vector.z,
            z: x * vector.y - y * vector.x
        )
    }

    static func +(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func -(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func *(lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        return SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    static func /(lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        return SCNVector3(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    }
}


extension FlutterArkitView {
    func initalize(_ arguments: [String: Any], _: FlutterResult) {
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .directional
        lightNode.light?.intensity = 1500
        lightNode.light?.castsShadow = true
        lightNode.eulerAngles = SCNVector3(-Float.pi / 3, 0, 0)
        sceneView.scene.rootNode.addChildNode(lightNode)

        if let showStatistics = arguments["showStatistics"] as? Bool {
            sceneView.showsStatistics = showStatistics
        }

        if let autoenablesDefaultLighting = arguments["autoenablesDefaultLighting"] as? Bool {
            sceneView.autoenablesDefaultLighting = autoenablesDefaultLighting
        }

        if let forceUserTapOnCenter = arguments["forceUserTapOnCenter"] as? Bool {
            forceTapOnCenter = forceUserTapOnCenter
        }

        initalizeGesutreRecognizers(arguments)

        sceneView.debugOptions = parseDebugOptions(arguments)
        configuration = parseConfiguration(arguments)
        configuration?.providesAudioData=true
        configuration?.frameSemantics = [.sceneDepth]
        
        if configuration != nil {
            print("FlutterArkitView: Running ARSession with configuration")
            sceneView.session.run(configuration!)
        }
       
    }

    func parseDebugOptions(_ arguments: [String: Any]) -> SCNDebugOptions {
        var options = ARSCNDebugOptions().rawValue
        if let showFeaturePoint = arguments["showFeaturePoints"] as? Bool {
            if showFeaturePoint {
                options |= ARSCNDebugOptions.showFeaturePoints.rawValue
            }
        }
        if let showWorldOrigin = arguments["showWorldOrigin"] as? Bool {
            if showWorldOrigin {
                options |= ARSCNDebugOptions.showWorldOrigin.rawValue
            }
        }
        return ARSCNDebugOptions(rawValue: options)
    }

    func parseConfiguration(_ arguments: [String: Any]) -> ARConfiguration? {
        let configurationType = arguments["configuration"] as! Int
        var configuration: ARConfiguration?

        switch configurationType {
        case 0:
            configuration = createWorldTrackingConfiguration(arguments)
        case 1:
            #if !DISABLE_TRUEDEPTH_API
                configuration = createFaceTrackingConfiguration(arguments)
            #else
                logPluginError("TRUEDEPTH_API disabled", toChannel: channel)
            #endif
        case 2:
            if #available(iOS 12.0, *) {
                configuration = createImageTrackingConfiguration(arguments)
            } else {
                logPluginError("configuration is not supported on this device", toChannel: channel)
            }
        case 3:
            if #available(iOS 13.0, *) {
                configuration = createBodyTrackingConfiguration(arguments)
            } else {
                logPluginError("configuration is not supported on this device", toChannel: channel)
            }
        case 4:
            if #available(iOS 14.0, *) {
                configuration = createDepthTrackingConfiguration(arguments)
            } else {
                logPluginError("configuration is not supported on this device", toChannel: channel)
            }
        default:
            break
        }
        configuration?.worldAlignment = parseWorldAlignment(arguments)
        return configuration
    }

    func parseWorldAlignment(_ arguments: [String: Any]) -> ARConfiguration.WorldAlignment {
        if let worldAlignment = arguments["worldAlignment"] as? Int {
            if worldAlignment == 0 {
                return .gravity
            }
            if worldAlignment == 1 {
                return .gravityAndHeading
            }
        }
        return .camera
    }
}
