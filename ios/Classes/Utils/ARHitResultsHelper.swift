import ARKit

func getARHitResultsArray(_ sceneView: ARSCNView, atLocation location: CGPoint) -> [[String: Any]] {
    let arHitResults = getARHitResults(sceneView, atLocation: location)
    let results = convertHitResultsToArray(arHitResults)
    return results
}

private func getARHitResults(_ sceneView: ARSCNView, atLocation location: CGPoint) -> [ARHitTestResult] {
    var types = ARHitTestResult.ResultType(
        [.featurePoint, .estimatedHorizontalPlane, .existingPlane, .existingPlaneUsingExtent, .estimatedVerticalPlane, .existingPlaneUsingGeometry])
    let results = sceneView.hitTest(location, types: types)
    return results
}

private func convertHitResultsToArray(_ array: [ARHitTestResult]) -> [[String: Any]] {
    return array.map { getDictFromHitResult($0) }
}

private func getDictFromHitResult(_ result: ARHitTestResult) -> [String: Any] {
    var dict = [String: Any](minimumCapacity: 4)
    dict["type"] = result.type.rawValue
    dict["distance"] = result.distance
    dict["localTransform"] = serializeMatrix(result.localTransform)
    dict["worldTransform"] = serializeMatrix(result.worldTransform)

    if let anchor = result.anchor {
        dict["anchor"] = serializeAnchor(anchor)
    }

    return dict
}

@available(iOS 13.0, *)
func getARRaycastResultsArray(_ sceneView: ARSCNView, atLocation location: CGPoint) -> [[String: Any]] {
    print("getARRaycastResultsArray")
    let arHitResults = getARRaycastResults(sceneView, atLocation: location)
    print("getARRaycastResultsArray 2")
    let results = convertARRaycastResultsToArray(arHitResults)
    print("getARRaycastResultsArray 3 \(results.count)")
    return results
}

@available(iOS 13.0, *)
private func getARRaycastResults(_ sceneView: ARSCNView, atLocation location: CGPoint) -> [ARRaycastResult] {
    print("getARRaycastResults")
    guard let query  = sceneView.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .any)
        else {
            print("getARRaycastResults Error")
            return []
        }


    let results = sceneView.session.raycast(query)
    return results
}

@available(iOS 13.0, *)
private func convertARRaycastResultsToArray(_ array: [ARRaycastResult]) -> [[String: Any]] {
    print("convertARRaycastResultsToArray \(array.count)")
    return array.map { getDictFromARRaycastResult($0) }
}

@available(iOS 13.0, *)
private func getDictFromARRaycastResult(_ result: ARRaycastResult) -> [String: Any] {
    var dict = [String: Any](minimumCapacity: 1)
    // dict["type"] = result.type.rawValue
    // dict["distance"] = result.distance
    // dict["localTransform"] = serializeMatrix(result.localTransform)
    print("getDictFromARRaycastResult \(result.worldTransform)")
    dict["worldTransform"] = serializeMatrix(result.worldTransform)

    if let anchor = result.anchor {
        dict["anchor"] = serializeAnchor(anchor)
    }

    return dict
}