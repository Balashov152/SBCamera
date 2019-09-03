//
//  SBCameraController.swift
//  Pods
//
//  Created by Sergey Balashov on 03/09/2019.
//

open class SBCameraController: UIViewController, SBCameraViewControllble {
    open var cameraView = UIView()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        view.addSubview(view)
        NSLayoutConstraint.activate([NSLayoutConstraint(item: cameraView, attribute: .left, relatedBy: .equal,
                                                        toItem: view, attribute: .left, multiplier: 1, constant: 0),
                                     NSLayoutConstraint(item: cameraView, attribute: .right, relatedBy: .equal,
                                                        toItem: view, attribute: .right, multiplier: 1, constant: 0),
                                     NSLayoutConstraint(item: cameraView, attribute: .top, relatedBy: .equal,
                                                        toItem: view, attribute: .topMargin, multiplier: 1, constant: 0),
                                     NSLayoutConstraint(item: cameraView, attribute: .height, relatedBy: .equal,
                                                        toItem: view, attribute: .height, multiplier: 1, constant: 0)])
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
