import ARKit
import Foundation

@available(iOS 13.0, *)
extension FlutterArkitView: ARCoachingOverlayViewDelegate {
    func addCoachingOverlay(_ arguments: [String: Any]) {
        guard let sceneView = viewController?.sceneView else{
            return
        }
        let goalType = arguments["goal"] as! Int
        let goal = ARCoachingOverlayView.Goal(rawValue: goalType)!

        let coachingView = ARCoachingOverlayView(frame: sceneView.frame)

        coachingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        removeCoachingOverlay()

        sceneView.addSubview(coachingView)

        coachingView.goal = goal
        coachingView.session = sceneView.session
        coachingView.delegate = self
        coachingView.setActive(true, animated: true)
    }

    func removeCoachingOverlay() {
        guard let sceneView = viewController?.sceneView else{
            return
        }
        if let view = sceneView.subviews.first(where: { $0 is ARCoachingOverlayView }) {
            view.removeFromSuperview()
        }
    }

    func coachingOverlayViewDidDeactivate(_: ARCoachingOverlayView) {
        sendToFlutter("coachingOverlayViewDidDeactivate", arguments: nil)
    }
}
