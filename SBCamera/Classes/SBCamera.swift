//
//  SBCamera.swift
//
//
//  Created by Sergey on 09.08.2018.
//  Copyright © 2018. All rights reserved.
//

import AVFoundation
import MediaPlayer
import MobileCoreServices
import Photos
import SwiftPermissionManager
import UIKit

public protocol SBCameraViewControllble {
    var cameraView: UIView { get }
}

public class SBCameraConfig {
    private init() {}
    static var isEnableVolumeButton = true
}

public protocol SBCameraDelegate: class {
    func didCreateUIImage(_ camera: SBCamera, image: UIImage)
    func didCreatePHAsset(_ camera: SBCamera, asset: PHAsset)
    func catchError(_ camera: SBCamera, error: Error)
}

public extension SBCamera {
    enum TypeMedia {
        case uiImage, phAssetImage
    }
}

open class SBCamera: NSObject {
    public typealias ViewController = UIViewController & SBCameraViewControllble
    
    public weak var viewController: ViewController?
    public weak var delegate: SBCameraDelegate?
    public var typeMedia: TypeMedia
    
    private lazy var cameraManager = CameraManager()
    private lazy var imagePickerController = UIImagePickerController()
    
    public init(controller: ViewController = SBCameraController(), typeMedia: TypeMedia) {
        self.viewController = controller
        self.typeMedia = typeMedia
        
        super.init()
        
        cameraManager.cameraOutputQuality = .high
        cameraManager.cameraDevice = .front
        
        if SBCameraConfig.isEnableVolumeButton {
            listenVolumeButton()
        }
    }
    
    deinit {
        unlistenVolumeButton()
        cameraManager.stopCaptureSession()
        cameraManager.deleteCameraManagersFiles()
    }
    
    //MARK: Public
    open func openLibrary() {
        PermissionManager().checkPermission(type: .photoLibrary, createRequestIfNeed: true, denied: {
            PermissionManager().openSettings(type: .photoLibrary)
        }) { [weak self] in
            DispatchQueue.main.async {
                self?.openImagePicker()
            }
        }
    }
    
    open func initCameraView() {
        PermissionManager().checkPermission(type: .camera, createRequestIfNeed: true, denied: {
            PermissionManager().openSettings(type: .camera)
        }) { [weak self] in
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = true
                self?.requestCamera()
            }
        }
    }
    
    open func capturePhoto() {
        switch typeMedia {
        case .uiImage:
            cameraManager.capturePictureImageWithCompletion { [weak self] image, error in
                guard let self = self else { return }
                if let error = error {
                    self.delegate?.catchError(self, error: error)
                } else if let image = image {
                    self.delegate?.didCreateUIImage(self, image: image)
                }
            }
        case .phAssetImage:
            cameraManager.capturePictureAssetWithCompletion { [weak self] asset, error in
                guard let self = self else { return }
                if let error = error {
                    self.delegate?.catchError(self, error: error)
                } else if let asset = asset {
                    self.delegate?.didCreatePHAsset(self, asset: asset)
                }
            }
        }
    }
    
    open func switchCamera() {
        let isFront = cameraManager.cameraDevice == .front
        cameraManager.cameraDevice = isFront ? .back : .front
    }
    
    //MARK: Private
    private func requestCamera() {
        switch cameraManager.currentCameraStatus() {
        case .accessDenied:
            PermissionManager().openSettings(type: .camera)
            
        case .ready:
            addCameraToView()
            
        default: break
        }
        
        cameraManager.resumeCaptureSession()
    }
    
    private func addCameraToView() {
        guard let cameraView = self.viewController?.cameraView else {
            return
        }
        cameraManager.addPreviewLayerToView(cameraView, newCameraOutputMode: CameraOutputMode.stillImage)
        
        //        cameraManager.showErrorBlock = { (_: String, erMessage: String) -> Void in
        //            showErrorOKAlert(message: erMessage)
        //        }
        
        cameraManager.shouldFlipFrontCameraImage = false // animation change front/back camera
    }
    
    private func openImagePicker() {
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        
        var mediaTypes = [String]()
        switch typeMedia {
        case .uiImage, .phAssetImage:
            mediaTypes = [kUTTypeImage as String]
        }
        
        imagePickerController.mediaTypes = mediaTypes
        viewController?.present(imagePickerController, animated: true)
    }
    
    private func doneSeletedMediaFromLibrary(pickerInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let mediaType = info[.mediaType] as? String else { return }
        print("Image Selected")
        
        switch typeMedia {
        case .phAssetImage:
            if mediaType == (kUTTypeImage as String) {
                if #available(iOS 11.0, *) {
                    if let asset = info[.phAsset] as? PHAsset {
                        delegate?.didCreatePHAsset(self, asset: asset)
                    }
                } else {
                    if let url = info[.referenceURL] as? URL {
                        if let asset = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil).firstObject {
                            delegate?.didCreatePHAsset(self, asset: asset)
                        }
                    }
                }
            }
            
        case .uiImage:
            if mediaType == (kUTTypeImage as String) {
                if let image = info[.originalImage] as? UIImage {
                    delegate?.didCreateUIImage(self, image: image)
                }
            }
            
        }
    }
}

extension SBCamera: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: { [weak self] in
            self?.doneSeletedMediaFromLibrary(pickerInfo: info)
        })
    }
}


public extension SBCamera {
    private func listenVolumeButton() {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.clipsToBounds = true
        viewController?.view.addSubview(volumeView)
        
        AVAudioSession.sharedInstance().addObserver(self, forKeyPath: "outputVolume", options: NSKeyValueObservingOptions.new, context: nil)
        do { try AVAudioSession.sharedInstance().setActive(true) } catch { debugPrint("\(error)") }
    }
    
    func unlistenVolumeButton() {
        AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
        do { try AVAudioSession.sharedInstance().setActive(false) } catch { debugPrint("\(error)") }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            //            capturePhoto()
        }
    }
}
