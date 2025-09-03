import ARKit

extension FlutterArkitView {
    func onAddNode(_ arguments: [String: Any]) {
        
        
        let geometryArguments = arguments["geometry"] as? [String: Any]
        let geometry = createGeometry(geometryArguments, withDevice: sceneView.device)
        let node = createNode(
            geometry, fromDict: arguments, forDevice: sceneView.device, channel: channel)
       

        if let parentNodeName = arguments["parentNodeName"] as? String {
            let parentNode = sceneView.scene.rootNode.childNode(
                withName: parentNodeName, recursively: true)
        
            if let translation = arguments["translation"] as? [String: Any],
                let x = translation["x"] as? Double,
                let y = translation["y"] as? Double,
                let z = translation["z"] as? Double
            {
                //let localPosition = parentNode.convertPosition(worldPosition, from: nil)
                DispatchQueue.main.async {
        
                    node.localTranslate(by: SCNVector3(x, y, z))
                    let containerNode = SCNNode()
                    containerNode.addChildNode(node)
                    parentNode?.addChildNode(containerNode)
                    print("Child translated to: \(node.position)")
                    
                    if let scale = arguments["scale"] as? [String: Any],
                        let x = scale["x"] as? Double,
                        let y = scale["y"] as? Double,
                       let z = scale["z"] as? Double{
                        
                        node.scale=SCNVector3(x,y, z)
                        node.geometry?.firstMaterial?.isDoubleSided = true
                    }

                }
            }
         
        
        } else {
            print("adding Sphere")

            sceneView.scene.rootNode.addChildNode(node)
        }
    }
    


    func animateNodePositionWithAction(
        _ node: SCNNode, to position: SCNVector3, duration: TimeInterval = 0.3
    ) {
        
        
        let moveAction = SCNAction.move(to: position, duration: duration)
        moveAction.timingMode = .easeInEaseOut
        node.runAction(
            moveAction
        )

        print("Translation comeplete")
    }
    
    
    
    
    

    func onUpdateNodes(_ arguments: [String: Any]) {
        print("Entering onUpdateNode")
        // Extract node name
        guard let nodeNames = arguments["nodeName"] as? [String] else {
            logPluginError("nodeName deserialization failed", toChannel: channel)
            return
        }
        print("[onUpdateNode] Updating node: \(nodeNames)")

        // Find the node in the scene by name
        let foundNodes: [SCNNode] = nodeNames.compactMap { name in
            let node = sceneView.scene.rootNode.childNode(withName: name, recursively: true)
            if node == nil {
                logPluginError("Node '\(name)' not found in scene", toChannel: channel)
                
            }
            if let geometryArguments = arguments["geometry"] as? [String: Any],
                let geometry = createGeometry(geometryArguments, withDevice: sceneView.device)
            {
                node?.geometry = geometry
                print("[onUpdateNode] Geometry updated for node: \(nodeNames)")
            }

            // Update materials if provided
            if let materials = arguments["materials"] as? [[String: Any]] {
                node?.geometry?.materials = parseMaterials(materials)
                print("[onUpdateNode] Materials updated for node: \(nodeNames)")
            }
            
            return node
        }
        print("[onUpdateNode] Found node: \(nodeNames)")

        // Update geometry if provided
       

        func normalized(_ v: SCNVector3) -> SCNVector3 {
            let len = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
            guard len > 0 else { return SCNVector3(0, 0, 0) }
            return SCNVector3(v.x / len, v.y / len, v.z / len)
        }

        func cross(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
            return SCNVector3(
                a.y * b.z - a.z * b.y,
                a.z * b.x - a.x * b.z,
                a.x * b.y - a.y * b.x
            )
        }

        if let start = arguments["startPoint"] as? [String: Any],
            let end = arguments["endPoint"] as? [String: Any],
            let sx = start["x"] as? Double, let sy = start["y"] as? Double,
            let sz = start["z"] as? Double,
            let ex = end["x"] as? Double, let ey = end["y"] as? Double, let ez = end["z"] as? Double
        {

            let startVec = SCNVector3(Float(sx), Float(sy), Float(sz))
            let endVec = SCNVector3(Float(ex), Float(ey), Float(ez))
            let center = SCNVector3((startVec.x+endVec.x)/2,(startVec.y+endVec.y)/2,(startVec.z+endVec.z)/2)

            // Move node instantly to startVec
            
            if foundNodes.isEmpty {return}
            
//            let localDirection = SCNVector3(1, 0, 0) // move along local X
////            let distance: Float = (foundNodes.first!.boundingBox.max.x - foundNodes.first!.boundingBox.min.x)*0.05
////
////            // Convert local direction to world space using the node’s transform
////            let worldDirection = foundNodes.first!.presentation.convertVector(localDirection, to: nil)
////            let newPosition = center + (worldDirection * distance)

            // Set orientation to align node’s forward with direction vector
           updateNodePositionAndOrientationSmoothly(node: foundNodes.first!, startVec: startVec, endVec: endVec,sceneView: sceneView)
            if let translation = arguments["translation"] as? [String: Any],
                let x = translation["x"] as? Double,
                let y = translation["y"] as? Double,
                let z = translation["z"] as? Double
            {
                animateNodePositionWithAction(
                    foundNodes.first!, to: center, duration: 0.3)

                print("[onUpdateNode] Node '\(nodeNames)' translated by x:\(x), y:\(y), z:\(z)")
                
          
            }
        }

        print("[onUpdateNode] Node '\(nodeNames)' update complete.")
    }

    func updateNodePositionAndOrientationSmoothly(
        node: SCNNode,
        startVec: SCNVector3,
        endVec: SCNVector3,
        sceneView: ARSCNView,
        faceCameraInitially: Bool = false,
        duration: CFTimeInterval = 0.2
    ) {


        // Step 1: Direction and length
        let direction = SCNVector3(
            x: endVec.x - startVec.x,
            y: endVec.y - startVec.y,
            z: endVec.z - startVec.z
        )
        let length = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)

        guard length > 0.0001 else {
            return
        }

        // Step 2: Scale factor
        let (minVec, maxVec) = node.boundingBox
        let originalLength = maxVec.x - minVec.x
        let scaleFactor = length / originalLength * 1.24

        // Step 3: Compute rotation quaternion
        let simdDir = simd_normalize(simd_float3(direction))
        let simdForward = simd_float3(1, 0, 0) // model default forward axis
        var q: simd_quatf
        let dot = simd_dot(simdForward, simdDir)
       

        if dot < -0.95 {
            var axis = simd_cross(simdForward, simd_float3(0, 1, 0))
            if simd_length_squared(axis) < 0.001 {
                axis = simd_cross(simdForward, simd_float3(0, 0, 1))
            }
            axis = simd_normalize(axis)
            q = simd_quatf(angle: .pi, axis: axis)
        } else {
            q = simd_quatf(from: simdForward, to: simdDir)
        }

        let lookRotation = SCNQuaternion(q.imag.x, q.imag.y, q.imag.z, q.real)

        // Step 4: Optional 90° correction
        let halfAngle = Float.pi / 4
        let sinHalf = sin(halfAngle)
        let cosHalf = cos(halfAngle)
        let xRotation = SCNQuaternion(sinHalf, 0, 0, cosHalf)

        let finalRotation = SCNQuaternion(
            lookRotation.x * xRotation.w + lookRotation.w * xRotation.x + lookRotation.y * xRotation.z - lookRotation.z * xRotation.y,
            lookRotation.y * xRotation.w + lookRotation.w * xRotation.y + lookRotation.z * xRotation.x - lookRotation.x * xRotation.z,
            lookRotation.z * xRotation.w + lookRotation.w * xRotation.z + lookRotation.x * xRotation.y - lookRotation.y * xRotation.x,
            lookRotation.w * xRotation.w - lookRotation.x * xRotation.x - lookRotation.y * xRotation.y - lookRotation.z * xRotation.z
        )

        // Step 5: Animate transform
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        node.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
        node.orientation=finalRotation
        SCNTransaction.commit()

        print("✅ Node update complete.\n")
    }



    func onRemoveNode(_ arguments: [String: Any]) {
        guard let nodeName = arguments["nodeName"] as? String else {
            logPluginError("nodeName deserialization failed", toChannel: channel)
            return
        }

        guard let node = sceneView.scene.rootNode.childNode(withName: nodeName, recursively: true) else {
            logPluginError("Node '\(nodeName)' not found for removal", toChannel: channel)
            return
        }

        // ✅ Release materials
        node.geometry?.materials.forEach { material in
            // Clear textures if any (they are heavy)
            material.diffuse.contents = nil
            material.normal.contents = nil
            material.ambient.contents = nil
            material.emission.contents = nil
            material.transparent.contents = nil
            material.reflective.contents = nil
            material.multiply.contents = nil
            material.specular.contents = nil
            material.metalness.contents = nil
            material.roughness.contents = nil
        }

        // ✅ Remove materials and geometry references
        node.geometry?.materials.removeAll()
        node.geometry = nil

        // ✅ Remove child nodes if any (recursive cleanup)
        node.enumerateChildNodes { child, _ in
            child.geometry?.materials.removeAll()
            child.geometry = nil
            child.removeFromParentNode()
        }

        // ✅ Finally remove node
        node.removeFromParentNode()
    }


//
//    func onRemoveNode(_ arguments: [String: Any]) {
//        guard let nodeName = arguments["nodeName"] as? String else {
//            logPluginError("nodeName deserialization failed", toChannel: channel)
//            return
//        }
//        let node = sceneView.scene.rootNode.childNode(withName: nodeName, recursively: true)
//        node?.removeFromParentNode()
//    }

    func onRemoveAnchor(_ arguments: [String: Any]) {
        guard let anchorIdentifier = arguments["anchorIdentifier"] as? String else {
            logPluginError("anchorIdentifier deserialization failed", toChannel: channel)
            return
        }
        if let anchor = sceneView.session.currentFrame?.anchors.first(where: {
            $0.identifier.uuidString == anchorIdentifier
        }) {
            sceneView.session.remove(anchor: anchor)
        }
    }

    func onGetNodeBoundingBox(_ arguments: [String: Any], _ result: FlutterResult) {
        guard let name = arguments["name"] as? String
        else {
            logPluginError("name not found: failed", toChannel: channel)
            return
        }
        if let node = sceneView.scene.rootNode.childNode(withName: name, recursively: true) {
            let resArray = [
                serializeVector(node.boundingBox.min), serializeVector(node.boundingBox.max),
            ]
            result(resArray)
        } else {
            logPluginError("node \(name) not found", toChannel: channel)
        }
    }

    func onTransformChanged(_ arguments: [String: Any]) {
        guard let name = arguments["name"] as? String,
            let params = arguments["transformation"] as? [NSNumber]
        else {
            logPluginError("deserialization failed", toChannel: channel)
            return
        }
        if let node = sceneView.scene.rootNode.childNode(withName: name, recursively: true) {
            node.transform = deserializeMatrix4(params)
        } else {
            logPluginError("node \(name) not found", toChannel: channel)
        }
    }

    func onIsHiddenChanged(_ arguments: [String: Any]) {
        guard let name = arguments["name"] as? String,
            let params = arguments["isHidden"] as? Bool
        else {
            logPluginError("deserialization failed", toChannel: channel)
            return
        }
        if let node = sceneView.scene.rootNode.childNode(withName: name, recursively: true) {
            node.isHidden = params
        } else {
            logPluginError("node not found", toChannel: channel)
        }
    }

    func onUpdateSingleProperty(_ arguments: [String: Any]) {
        guard let name = arguments["name"] as? String,
            let args = arguments["property"] as? [String: Any],
            let propertyName = args["propertyName"] as? String,
            let propertyValue = args["propertyValue"],
            let keyProperty = args["keyProperty"] as? String
        else {
            logPluginError("deserialization failed", toChannel: channel)
            return
        }

        if let node = sceneView.scene.rootNode.childNode(withName: name, recursively: true) {
            if let obj = node.value(forKey: keyProperty) as? NSObject {
                obj.setValue(propertyValue, forKey: propertyName)
            } else {
                logPluginError("value is not a NSObject", toChannel: channel)
            }
        } else {
            logPluginError("node not found", toChannel: channel)
        }
    }

    func onUpdateMaterials(_ arguments: [String: Any]) {
        guard let name = arguments["name"] as? String,
            let rawMaterials = arguments["materials"] as? [[String: Any]]
        else {
            logPluginError("deserialization failed", toChannel: channel)
            return
        }
        if let node = sceneView.scene.rootNode.childNode(withName: name, recursively: true) {
            let materials = parseMaterials(rawMaterials)
            node.geometry?.materials = materials
        } else {
            logPluginError("node not found", toChannel: channel)
        }
    }

    func onUpdateFaceGeometry(_ arguments: [String: Any]) {
        #if !DISABLE_TRUEDEPTH_API
            guard let name = arguments["name"] as? String,
                let param = arguments["geometry"] as? [String: Any],
                let fromAnchorId = param["fromAnchorId"] as? String
            else {
                logPluginError("deserialization failed", toChannel: channel)
                return
            }
            if let node = sceneView.scene.rootNode.childNode(withName: name, recursively: true),
                let geometry = node.geometry as? ARSCNFaceGeometry,
                let anchor = sceneView.session.currentFrame?.anchors.first(where: {
                    $0.identifier.uuidString == fromAnchorId
                }) as? ARFaceAnchor
            {
                geometry.update(from: anchor.geometry)
            } else {
                logPluginError(
                    "node not found, geometry was empty, or anchor not found", toChannel: channel)
            }
        #else
            logPluginError("TRUEDEPTH_API disabled", toChannel: channel)
        #endif
    }

    func onPerformHitTest(_ arguments: [String: Any], _ result: FlutterResult) {
        guard let x = arguments["x"] as? Double,
            let y = arguments["y"] as? Double
        else {
            logPluginError("deserialization failed", toChannel: channel)
            result(nil)
            return
        }
        let viewWidth = sceneView.bounds.size.width
        let viewHeight = sceneView.bounds.size.height
        let location = CGPoint(x: viewWidth * CGFloat(x), y: viewHeight * CGFloat(y))
        let arHitResults = getARHitResultsArray(sceneView, atLocation: location)
        result(arHitResults)
    }

    func onPerformARRaycastHitTest(_ arguments: [String: Any], _ result: FlutterResult) {
        guard let x = arguments["x"] as? Double,
            let y = arguments["y"] as? Double
        else {
            logPluginError("deserialization failed", toChannel: channel)
            result(nil)
            return
        }
        let viewWidth = sceneView.bounds.size.width
        let viewHeight = sceneView.bounds.size.height
        print(viewWidth,"x",viewHeight)
        let location = CGPoint(x: viewWidth * CGFloat(x), y: viewHeight * CGFloat(y))
        let arHitResults = getARRaycastResultsArray(sceneView, atLocation: location)
        result(arHitResults)
    }

    func onGetLightEstimate(_ result: FlutterResult) {
        let frame = sceneView.session.currentFrame
        if let lightEstimate = frame?.lightEstimate {
            let res = [
                "ambientIntensity": lightEstimate.ambientIntensity,
                "ambientColorTemperature": lightEstimate.ambientColorTemperature,
            ]
            result(res)
        } else {
            result(nil)
        }
    }

    func onProjectPoint(_ arguments: [String: Any], _ result: FlutterResult) {
        guard let rawPoint = arguments["point"] as? [Double] else {
            logPluginError("deserialization failed", toChannel: channel)
            result(nil)
            return
        }
        let point = deserizlieVector3(rawPoint)
        let projectedPoint = sceneView.projectPoint(point)
        let res = serializeVector(projectedPoint)
        result(res)
    }

    func onCameraProjectionMatrix(_ result: FlutterResult) {
        if let frame = sceneView.session.currentFrame {
            let matrix = serializeMatrix(frame.camera.projectionMatrix)
            result(matrix)
        } else {
            result(nil)
        }
    }

    func onCameraViewMatrix(_ result: FlutterResult) {
        if let frame = sceneView.session.currentFrame {

            let matrix = serializeMatrix(frame.camera.viewMatrix(for: .portrait))
            result(matrix)
        } else {
            result(nil)
        }
    }

    func onCameraTransform(_ result: FlutterResult) {
        if let frame = sceneView.session.currentFrame {
            let matrix = serializeMatrix(frame.camera.transform)
            result(matrix)
        } else {
            result(nil)
        }
    }

    func onPointOfViewTransform(_ result: FlutterResult) {
        if let pointOfView = sceneView.pointOfView {
            let matrix = serializeMatrix(pointOfView.simdWorldTransform)
            result(matrix)
        } else {
            result(nil)
        }
    }

    func onPlayAnimation(_ arguments: [String: Any]) {
        guard let key = arguments["key"] as? String,
            let sceneName = arguments["sceneName"] as? String,
            let animationIdentifier = arguments["animationIdentifier"] as? String
        else {
            logPluginError("deserialization failed", toChannel: channel)
            return
        }

        if let sceneUrl = Bundle.main.url(forResource: sceneName, withExtension: "dae"),
            let sceneSource = SCNSceneSource(url: sceneUrl, options: nil),
            let animation = sceneSource.entryWithIdentifier(
                animationIdentifier, withClass: CAAnimation.self)
        {
            animation.repeatCount = 1
            animation.fadeInDuration = 1
            animation.fadeOutDuration = 0.5
            sceneView.scene.rootNode.addAnimation(animation, forKey: key)
        } else {
            logPluginError("animation failed", toChannel: channel)
        }
    }

    func onStopAnimation(_ arguments: [String: Any]) {
        guard let key = arguments["key"] as? String else {
            logPluginError("deserialization failed", toChannel: channel)
            return
        }
        sceneView.scene.rootNode.removeAnimation(forKey: key)
    }

    func onCameraEulerAngles(_ result: FlutterResult) {
        if let frame = sceneView.session.currentFrame {
            let res = serializeArray(frame.camera.eulerAngles)
            result(res)
        } else {
            result(nil)
        }
    }

    func onCameraIntrinsics(_ result: FlutterResult) {
        if let frame = sceneView.session.currentFrame {
            let res = serializeMatrix3x3(frame.camera.intrinsics)
            result(res)
        } else {
            result(nil)
        }
    }

    func onCameraImageResolution(_ result: FlutterResult) {
        if let frame = sceneView.session.currentFrame {
            let res = serializeSize(frame.camera.imageResolution)
            result(res)
        } else {
            result(nil)
        }
    }

    func onCameraCapturedImage(_ result: FlutterResult) {
        if let frame = sceneView.session.currentFrame {
            if let bytes = UIImage(ciImage: CIImage(cvPixelBuffer: frame.capturedImage)).pngData() {
                let res = FlutterStandardTypedData(bytes: bytes)
                result(res)
            } else {
                result(nil)
            }
        } else {
            result(nil)
        }
    }

    func onGetSnapshot(_ result: FlutterResult) {
        let snapshotImage = sceneView.snapshot()
        if let bytes = snapshotImage.pngData() {
            let data = FlutterStandardTypedData(bytes: bytes)
            result(data)
        } else {
            result(nil)
        }
    }
    


    func onGetSnapshotWithDepthData(_ result: FlutterResult) {
        if #available(iOS 14.0, *) {
            if let currentFrame = sceneView.session.currentFrame,
                let depthData = currentFrame.sceneDepth
            {
                let originalImage = currentFrame.capturedImage
                let ciImage = CIImage(cvPixelBuffer: originalImage)
                let ciContext = CIContext()
                let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)!
                let image = UIImage(cgImage: cgImage)
                let convertedImage = image.jpegData(compressionQuality: 1)!
                let imageData = FlutterStandardTypedData(bytes: convertedImage)

                let depthDataMap = depthData.depthMap

                CVPixelBufferLockBaseAddress(depthDataMap, CVPixelBufferLockFlags(rawValue: 0))

                let depthWidth = CVPixelBufferGetWidth(depthDataMap)
                let depthHeight = CVPixelBufferGetHeight(depthDataMap)

                let floatBuffer = unsafeBitCast(
                    CVPixelBufferGetBaseAddress(depthDataMap),
                    to: UnsafeMutablePointer<Float32>.self)

                CVPixelBufferUnlockBaseAddress(depthDataMap, CVPixelBufferLockFlags(rawValue: 0))

                let intrinsics = currentFrame.camera.intrinsics
                let intrinsicsString = String(
                    format: "%f,%f,%f-%f,%f,%f-%f,%f,%f",
                    intrinsics.columns.0.x, intrinsics.columns.0.y, intrinsics.columns.0.z,
                    intrinsics.columns.1.x, intrinsics.columns.1.y, intrinsics.columns.1.z,
                    intrinsics.columns.2.x, intrinsics.columns.2.y, intrinsics.columns.2.z
                )

                let depthArray = Array(
                    UnsafeBufferPointer(start: floatBuffer, count: depthWidth * depthHeight)
                ).map { $0.isNaN ? -1 : $0 }
                let transform = currentFrame.camera.transform
                let transformString = String(
                    format: "%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f",
                    transform.columns.0.x, transform.columns.0.y, transform.columns.0.z,
                    transform.columns.0.w, transform.columns.1.x, transform.columns.1.y,
                    transform.columns.1.z, transform.columns.1.w, transform.columns.2.x,
                    transform.columns.2.y, transform.columns.2.z, transform.columns.2.w,
                    transform.columns.3.x, transform.columns.3.y, transform.columns.3.z,
                    transform.columns.3.w

                )

                let data: [String: Any] = [
                    "image": imageData,
                    "intrinsics": intrinsicsString,
                    "depthWidth": depthWidth,
                    "depthHeight": depthHeight,
                    "depthMap": depthArray,
                    "transform": transformString,
                ]

                result(data)
            } else {
                result(nil)
            }
        } else {
            result(nil)
        }
    }

    func onGetCameraPosition(_ result: FlutterResult) {
        if let frame: ARFrame = sceneView.session.currentFrame {
            let cameraPosition = frame.camera.transform.columns.3
            let res = serializeArray(cameraPosition)
            result(res)
        } else {
            result(nil)
        }
    }
    func toggleTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else {
            print("Torch not available")
            return
        }

        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used: \(error)")
        }
    }
}
