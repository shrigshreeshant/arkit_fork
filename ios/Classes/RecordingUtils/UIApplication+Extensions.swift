//
//  UIApplication+Extensions.swift
//  lidar_camera
//
//  Created by Shrig Solutions on 19/09/2024.
//

import Foundation

extension UIApplication {
    var keyWindow: UIWindow? {
            // For iOS 15.0 and later, use UIWindowScene.keyWindow
            if #available(iOS 15.0, *) {
                return self.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .filter { $0.activationState == .foregroundActive }
                    .first?
                    .keyWindow
            } else {
                // Fallback for iOS 14 and earlier
                return self.connectedScenes
                    .filter { $0.activationState == .foregroundActive }
                    .compactMap { $0 as? UIWindowScene }
                    .first?
                    .windows
                    .first(where: \.isKeyWindow)
            }
        }
    
    var keyWindowPresentedController: UIViewController? {
        var viewController = self.keyWindow?.rootViewController
        
        // If root `UIViewController` is a `UITabBarController`
        if let presentedController = viewController as? UITabBarController {
            // Move to selected `UIViewController`
            viewController = presentedController.selectedViewController
        }
        
        // Go deeper to find the last presented `UIViewController`
        while let presentedController = viewController?.presentedViewController {
            // If root `UIViewController` is a `UITabBarController`
            if let presentedController = presentedController as? UITabBarController {
                // Move to selected `UIViewController`
                viewController = presentedController.selectedViewController
            } else {
                // Otherwise, go deeper
                viewController = presentedController
            }
        }
        
        return viewController
    }
    
    
    /// Executes a closure when the key window's view controller is ready
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts (default: 10)
    ///   - delay: Delay between retries in seconds (default: 0.1)
    ///   - action: The closure to execute when view controller is ready
    func executeWhenViewControllerReady(
        maxRetries: Int = 10,
        delay: TimeInterval = 0.1,
        action: @escaping () -> Void
    ) {
        executeWhenViewControllerReady(
            retriesLeft: maxRetries,
            delay: delay,
            action: action
        )
    }
    
    private func executeWhenViewControllerReady(
        retriesLeft: Int,
        delay: TimeInterval,
        action: @escaping () -> Void
    ) {
        // Check if view controller is available
        if keyWindowPresentedController != nil {
            action()
        } else if retriesLeft > 0 {
            // Retry after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.executeWhenViewControllerReady(
                    retriesLeft: retriesLeft - 1,
                    delay: delay,
                    action: action
                )
            }
        } else {
            // Max retries reached - this will trigger the error handling in the calling code
            print("Failed to get view controller after maximum retries")
        }
    }
}
