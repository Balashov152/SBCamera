//
//  CameraManager+Alert.swift
//  SBCamera
//
//  Created by Sergey Balashov on 30.10.2020.
//

import Foundation
import UIKit

extension CameraManager {
    func _show(_ title: String, message: String) {
        if showErrorsToUsers {
            DispatchQueue.main.async(execute: {
                self.showErrorBlock(title, message)
            })
        }
    }
    
    /// A block creating UI to present error message to the user. This can be customised to be presented on the Window root view controller, or to pass in the viewController which will present the UIAlertController, for example.
    open func showErrorBlock(_ erTitle: String, _ erMessage: String) -> Void {
        
        var alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { (alertAction) -> Void in  }))
        
        if let topController = UIApplication.shared.keyWindow?.rootViewController {
            topController.present(alertController, animated: true, completion:nil)
        }
    }
}
