//
//  SBCameraConfig.swift
//  Pods
//
//  Created by Sergey Balashov on 04/09/2019.
//

extension SBCamera {
    open var cameraPosition: CameraDevice {
        get {
            return cameraManager.cameraDevice
        } set {
            cameraManager.cameraDevice = newValue
        }
    }
    
    open var cameraOutputQuality: CameraOutputQuality {
        get {
            return cameraManager.cameraOutputQuality
        } set {
            cameraManager.cameraOutputQuality = newValue
        }
    }
    
    open var shouldFlipFrontCameraImage: Bool {
        get {
            return cameraManager.shouldFlipFrontCameraImage
        } set {
            cameraManager.shouldFlipFrontCameraImage = newValue
        }
    }
    
    open var writeFilesToPhoneLibrary: Bool {
        get {
            return cameraManager.writeFilesToPhoneLibrary
        } set {
            cameraManager.writeFilesToPhoneLibrary = newValue
        }
    }
    
    open var cropImageToSizeCameraView: Bool {
        get {
            return cameraManager.cropImageToSizeCameraView
        } set {
            cameraManager.cropImageToSizeCameraView = newValue
        }
    }
    
}
