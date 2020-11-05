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
import PhotosUI

public protocol SBCameraViewControllble {
    var cameraView: UIView { get }
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
    
    open weak var viewController: ViewController?
    open weak var delegate: SBCameraDelegate?
    open var typeMedia: TypeMedia
    
    open var isEnableVolumeButton = true
    
    open var cropMode: RSKImageCropMode = .square
    
    /// open cropper screen after capture select photo from library
    /// if you want set typeMedia to phAsset, that cropped image will be save on photo library
    open var isNeedOpenRSKImageCropperLibrary = true
    
    /// open cropper screen after capture camera photo
    /// if you want set typeMedia to phAsset, that cropped image will be save on photo library
    open var isNeedOpenRSKImageCropperCamera = true

    open var possibleEmptySpaceAroundCroppedImage = false
    
    public lazy var imageManager = PHCachingImageManager.default()
    public lazy var photoOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        return options
    }()
    
    public lazy var cameraManager = CameraManager()
    public var imagePickerController: UIViewController?
    public var imagePickerSelectionLimit: Int = 1
    
    public var currentPhotoLibraryPermissionIsLimited: Bool = false
    
    public init(controller: ViewController, typeMedia: TypeMedia) {
        self.viewController = controller
        self.typeMedia = typeMedia
        
        super.init()
        
        if isEnableVolumeButton {
            listenVolumeButton()
        }
    }
    
    deinit {
        unlistenVolumeButton()
        cameraManager.stopCaptureSession()
        cameraManager.deleteCameraManagersFiles()
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    //MARK: Public
    open func openLibrary() {
        guard Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") != nil else {
            assertionFailure("Need fill key NSPhotoLibraryUsageDescription in Info.plist")
            return
        }
        
        PermissionManager().checkPhotoLibraryPermission(request: .readWrite, result: { [weak self] (result) in
            switch result {
            case let .success(type):
                self?.currentPhotoLibraryPermissionIsLimited = type == .photoLibraryLimited
                DispatchQueue.main.async {
                    self?.openImagePicker()
                }
            case let .failure(error):
                debugPrint("checkPhotoLibraryPermission error - \(error.localizedDescription)")
                PermissionManager().openSettings(type: .photoLibrary, localized: SBCamera.permissionManagerLocalizedForPhotoAlert)
            }
        })
    }
    
    private func checkCameraPermission(access: @escaping () -> ()) {
        PermissionManager().checkCameraPermission(request: true, result: { (result) in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    access()
                }
            case let .failure(error):
                debugPrint("checkCameraPermission error - \(error.localizedDescription)")
                PermissionManager().openSettings(type: .camera, localized: SBCamera.permissionManagerLocalizedForCameraAlert)
            }
        })
    }
    
    open func initCameraView() {
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
            assertionFailure("Need fill key NSCameraUsageDescription in Info.plist")
            return
        }
        checkCameraPermission { [weak self] in
            UIApplication.shared.isIdleTimerDisabled = true
            self?.requestCamera()
        }
    }
    
    open func capturePhoto() {
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
            assertionFailure("Need fill key NSCameraUsageDescription in Info.plist")
            return
        }
        
        checkCameraPermission { [weak self] in
            UIApplication.shared.isIdleTimerDisabled = true
            self?.capturePicturePhoto()
        }
    }
    
    private func capturePicturePhoto() {
        cameraManager.capturePictureWithCompletion { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case let .success(content: content):
                switch content {
                case let .asset(asset):
                    self.delegate?.sbCamera(self, didCreatePHAsset: asset)
                case let .image(image):
                    if self.isNeedOpenRSKImageCropperCamera {
                        self.cropImage(image: image)
                    } else {
                        self.delegate?.sbCamera(self, didCreateUIImage: image)
                    }
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
            PermissionManager().openSettings(type: .camera, localized: SBCamera.permissionManagerLocalizedForPhotoAlert)
            
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
        if imagePickerController == nil { // if need use standart UIImagePickerController
            imagePickerController = createUIImagePickerController()
        }
        
        guard let imagePickerController = imagePickerController else {
            assertionFailure("unreal case")
            return
        }
        
        viewController?.present(imagePickerController, animated: true)
    }
    
    private func createUIImagePickerController() -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
         imagePicker.sourceType = .photoLibrary
         imagePicker.delegate = self
         var mediaTypes = [String]()
         switch typeMedia {
         case .uiImage, .phAssetImage:
             mediaTypes = [kUTTypeImage as String]
         }
         
         imagePicker.mediaTypes = mediaTypes
        return imagePicker
    }
    
    private func doneSeletedMediaFromLibrary(pickerInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let mediaType = info[.mediaType] as? String else { return }
        print("Image selected from library")
        
        switch typeMedia {
        case .phAssetImage:
            if mediaType == (kUTTypeImage as String) {
                
                if #available(iOS 14.0, *), currentPhotoLibraryPermissionIsLimited,
                   let image = info[.originalImage] as? UIImage {
                    didGetImageFromPhotoLibrary(image: image)
                } else if #available(iOS 11.0, *) {
                    if let asset = info[.phAsset] as? PHAsset {
                        didGetAssetFromPhotoLibrary(asset: asset)
                    }
                } else {
                    if let url = info[.referenceURL] as? URL {
                        if let asset = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil).firstObject {
                            didGetAssetFromPhotoLibrary(asset: asset)
                        }
                    }
                }
            }
            
        case .uiImage:
            if mediaType == (kUTTypeImage as String) {
                if let image = info[.originalImage] as? UIImage {
                    didGetImageFromPhotoLibrary(image: image)
                }
            }
            
        }
    }
    
    private func didGetAssetFromPhotoLibrary(asset: PHAsset) {
        if isNeedOpenRSKImageCropperLibrary {
            requestImage(for: asset) { [weak self] (image) in
                self?.cropImage(image: image)
            }
        } else {
            delegate?.sbCamera(self, didCreatePHAsset: asset)
        }
    }
    
    private func didGetImageFromPhotoLibrary(image: UIImage) {
        if isNeedOpenRSKImageCropperLibrary {
            cropImage(image: image)
        } else {
            delegate?.sbCamera(self, didCreateUIImage: image)
        }
    }
    
    private func cropImage(image: UIImage) {
        let cropper = RSKImageCropViewController(image: image, cropMode: cropMode)
        cropper.delegate = self
        cropper.avoidEmptySpaceAroundImage = !possibleEmptySpaceAroundCroppedImage
        cropper.modalPresentationStyle = .fullScreen
        viewController?.present(cropper, animated: true, completion: nil)
    }
    
    private func didCropImage(image: UIImage) {
        switch typeMedia {
        case .phAssetImage:
            PermissionManager().checkPhotoLibraryPermission(request: .readWrite, result: { [weak self] (result) in
                switch result {
                case let .success(type):
                    guard type == .photoLibrary else {
                        print("permission photo library is limited, not save")
                        guard let self = self else { return }
                        self.delegate?.sbCamera(self, didCreateUIImage: image)
                        return
                    }
                    
                    self?.cameraManager.saveImageToPhotoLibrary(image: image) { [weak self] (result) in
                        guard let self = self else {
                            assertionFailure("weak self is nil")
                            return
                        }
                        
                        switch result {
                        case let .success(content):
                            switch content {
                            case let .asset(asset):
                                self.delegate?.sbCamera(self, didCreatePHAsset: asset)
                            case let .image(image):
                                assertionFailure("not call this conent for typeMedia == .phAssetImage")
                                self.delegate?.sbCamera(self, didCreateUIImage: image)
                            case .imageData:
                                assertionFailure("not implement case")
                            }
                        case let .failure(error):
                            self.delegate?.sbCamera(self, catchError: error)
                        }
                    }
                case let .failure(error):
                    print("permission photo library is denied reason - \(error)")
                    guard let self = self else { return }
                    self.delegate?.sbCamera(self, didCreateUIImage: image)
                }
            })

        case .uiImage:
            delegate?.sbCamera(self, didCreateUIImage: image)
        }
    }
    
    
    func requestImage(for asset: PHAsset, completion: @escaping (UIImage) -> Void) -> PHImageRequestID {
        let targetSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        return imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: photoOptions) { image, info in
            guard let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, !isDegraded, let image = image else { return }
            completion(image)
        }
    }
}

extension SBCamera: RSKImageCropViewControllerDelegate {
    public func imageCropViewControllerDidCancelCrop(_ controller: RSKImageCropViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    public func imageCropViewController(_ controller: RSKImageCropViewController, didCropImage croppedImage: UIImage, usingCropRect cropRect: CGRect, rotationAngle: CGFloat) {
        didCropImage(image: croppedImage)
        controller.dismiss(animated: true)
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
