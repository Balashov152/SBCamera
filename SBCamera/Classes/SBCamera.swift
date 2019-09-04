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
import RSKImageCropper

public protocol SBCameraViewControllble {
    var cameraView: UIView { get }
}

public class SBCameraConfig {
    private init() {}
    static var isEnableVolumeButton = true
    static var writeFilesToPhoneLibrary = true
    static var shouldFlipFrontCameraImage = false
    static var cropImageToSizeCameraView = true
    
    static var cropMode: RSKImageCropMode = .square
    static var isNeedOpenRSKImageCropper = true
    
}

public protocol SBCameraDelegate: class {
    func sbCamera(_ camera: SBCamera, didCreateUIImage image: UIImage)
    func sbCamera(_ camera: SBCamera, didCreatePHAsset asset: PHAsset)
    func sbCamera(_ camera: SBCamera, catchError error: Error)
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
    
    public init(controller: ViewController, typeMedia: TypeMedia) {
        self.viewController = controller
        self.typeMedia = typeMedia
        
        super.init()
        
        cameraManager.cameraOutputQuality = .high
        cameraManager.cameraDevice = .front
        cameraManager.shouldFlipFrontCameraImage = SBCameraConfig.shouldFlipFrontCameraImage
        cameraManager.writeFilesToPhoneLibrary = SBCameraConfig.writeFilesToPhoneLibrary
        cameraManager.cropImageToSizeCameraView = SBCameraConfig.cropImageToSizeCameraView
        
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
        guard Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") != nil else {
            assertionFailure("Need fill key NSPhotoLibraryUsageDescription in Info.plist")
            return
        }
        PermissionManager().checkPermission(type: .photoLibrary, createRequestIfNeed: true, denied: {
            PermissionManager().openSettings(type: .photoLibrary)
        }) { [weak self] in
            DispatchQueue.main.async {
                self?.openImagePicker()
            }
        }
    }
    
    open func initCameraView() {
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
            assertionFailure("Need fill key NSCameraUsageDescription in Info.plist")
            return
        }
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
        cameraManager.capturePictureWithCompletion { (result) in
            switch result {
            case let .success(content: content):
                switch content {
                case let .asset(asset):
                    self.delegate?.sbCamera(self, didCreatePHAsset: asset)
                case let .image(image):
                    self.delegate?.sbCamera(self, didCreateUIImage: image)
                case let .imageData(data):
                    debugPrint("imageData(data)", data)
                }
            case let .failure(error):
                self.delegate?.sbCamera(self, catchError: error)
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
        print("Image selected from library")
        
        switch typeMedia {
        case .phAssetImage:
            if mediaType == (kUTTypeImage as String) {
                if #available(iOS 11.0, *) {
                    if let asset = info[.phAsset] as? PHAsset {
                        delegate?.sbCamera(self, didCreatePHAsset: asset)
                    }
                } else {
                    if let url = info[.referenceURL] as? URL {
                        if let asset = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil).firstObject {
                            delegate?.sbCamera(self, didCreatePHAsset: asset)
                        }
                    }
                }
            }
            
        case .uiImage:
            if mediaType == (kUTTypeImage as String) {
                if let image = info[.originalImage] as? UIImage {
                    if SBCameraConfig.isNeedOpenRSKImageCropper {
                        cropImage(image: image)
                    } else {
                        delegate?.sbCamera(self, didCreateUIImage: image)
                    }
                }
            }
            
        }
    }
    
    private func cropImage(image: UIImage) {
        let cropper = RSKImageCropViewController(image: image, cropMode: SBCameraConfig.cropMode)
        cropper.delegate = self
        viewController?.present(cropper, animated: true, completion: nil)
    }
}

extension SBCamera: RSKImageCropViewControllerDelegate {
    public func imageCropViewControllerDidCancelCrop(_ controller: RSKImageCropViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    public func imageCropViewController(_ controller: RSKImageCropViewController, didCropImage croppedImage: UIImage, usingCropRect cropRect: CGRect, rotationAngle: CGFloat) {
        controller.dismiss(animated: true, completion: { [weak self] in
            if let self = self {
                self.delegate?.sbCamera(self, didCreateUIImage: croppedImage)
            }
        })
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
            capturePhoto()
        }
    }
}
