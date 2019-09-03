//
//  HistoryCameraViewController.swift
//
//
//  Created by Sergey on 09.08.2018.
//  Copyright © 2018. All rights reserved.
//

import SBCamera
import UIKit
import Photos

class CameraViewController: UIViewController, SBCameraViewControllble {
    var cameraView: UIView { cameraViewOutlet }
    @IBOutlet var cameraViewOutlet: UIView!
    @IBOutlet var closeButton: UIButton!

    @IBOutlet var actionButton: UIButton!

    @IBOutlet var galeryButton: UIButton!
    @IBOutlet var switchCamera: UIButton!

    private lazy var sbCamera = SBCamera(controller: self, typeMedia: .uiImage)
    
    public var didCreatePhoto: (UIImage) -> () = { _ in }

    override func viewDidLoad() {
        super.viewDidLoad()
        sbCamera.delegate = self
        sbCamera.initCameraView()
    }

    // MARK: Actions

    @IBAction func closeButtonAction(_: UIButton) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func actionButtonPhoto(_: UIButton) {
        sbCamera.capturePhoto()
    }

    @IBAction func switchCameraAction(_: UIButton) {
        sbCamera.switchCamera()
    }

    @IBAction func galeryButtonAction(_: UIButton) {
        sbCamera.openLibrary()
    }
}

extension CameraViewController: SBCameraDelegate {
    func sbCamera(_ camera: SBCamera, didCreatePHAsset asset: PHAsset) {
        
    }
    
    func sbCamera(_ camera: SBCamera, catchError error: Error) {
        
    }
    
    func sbCamera(_ camera: SBCamera, didCreateUIImage image: UIImage) {
        didCreatePhoto(image)
    }
}
