//
//  PHPhotoLibrary+Ex.swift
//  Pods
//
//  Created by Sergey Balashov on 03/09/2019.
//

import UIKit
import AVFoundation
import Photos
import PhotosUI
import ImageIO
import MobileCoreServices
import CoreLocation
import CoreMotion
import CoreImage

public extension PHPhotoLibrary {
    
    // MARK: - Public
    
    // finds or creates an album
    
    func getAlbum(name: String, completion: @escaping (PHAssetCollection?) -> ()) {
        if let album = self.findAlbum(name: name) {
            completion(album)
        } else {
            createAlbum(name: name, completion: completion)
        }
    }
    
    func save(image: UIImage, albumName: String?, date: Date = Date(), location: CLLocation? = nil, completion:((PHAsset?) -> ())? = nil) {
        func save() {
            if let albumName = albumName {
                self.getAlbum(name: albumName) { album in
                    guard let album = album else {
                        completion?(nil)
                        return
                    }
                    self.saveImage(image: image, album: album, date: date, location: location, completion: completion)
                }
            }
        }
        
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            save()
        } else {
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == .authorized {
                    save()
                } else {
                    completion?(nil)
                }
            })
        }
    }
    
    func save(videoAtURL: URL, albumName: String?, date: Date = Date(), location: CLLocation? = nil, completion:((PHAsset?) -> ())? = nil) {
        func save() {
            if let albumName = albumName {
                self.getAlbum(name: albumName) { album in
                    self.saveVideo(videoAtURL: videoAtURL, album: album, date: date, location: location, completion: completion)
                }
            } else {
                self.saveVideo(videoAtURL: videoAtURL, album: nil, date: date, location: location, completion: completion)
            }
            
        }
        
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            save()
        } else {
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == .authorized {
                    save()
                }
            })
        }
    }
    

    // MARK: - Private
    
    fileprivate func findAlbum(name: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", name)
        let fetchResult : PHFetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        guard let photoAlbum = fetchResult.firstObject else {
            return nil
        }
        return photoAlbum
    }
    
    fileprivate func createAlbum(name: String, completion: @escaping (PHAssetCollection?) -> ()) {
        var placeholder: PHObjectPlaceholder?
        
        self.performChanges({
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = createAlbumRequest.placeholderForCreatedAssetCollection
        }, completionHandler: { success, error in
            if let placeholder = placeholder {
                let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                completion(fetchResult.firstObject)
            }
            completion(nil)
        })
    }

    fileprivate func saveVideo(videoAtURL: URL, album: PHAssetCollection?, date: Date = Date(), location: CLLocation? = nil, completion:((PHAsset?) -> ())? = nil) {
        var placeholder: PHObjectPlaceholder?
        self.performChanges({
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoAtURL)!
            createAssetRequest.creationDate = date
            createAssetRequest.location = location
            if let album = album {
                guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                    let photoPlaceholder = createAssetRequest.placeholderForCreatedAsset else { return }
                placeholder = photoPlaceholder
                let fastEnumeration = NSArray(array: [photoPlaceholder] as [PHObjectPlaceholder])
                albumChangeRequest.addAssets(fastEnumeration)
                
            }
            
        }, completionHandler: { success, error in
            guard let placeholder = placeholder else {
                completion?(nil)
                return
            }
            if success {
                let assets:PHFetchResult<PHAsset> =  PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                let asset:PHAsset? = assets.firstObject
                completion?(asset)
            } else {
                completion?(nil)
            }
        })
    }
    
    fileprivate func saveImage(image: UIImage, album: PHAssetCollection, date: Date = Date(), location: CLLocation? = nil, completion:((PHAsset?)->())? = nil) {
        var placeholder: PHObjectPlaceholder?
        self.performChanges({
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            createAssetRequest.creationDate = date
            createAssetRequest.location = location
            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                let photoPlaceholder = createAssetRequest.placeholderForCreatedAsset else { return }
            placeholder = photoPlaceholder
            let fastEnumeration = NSArray(array: [photoPlaceholder] as [PHObjectPlaceholder])
            albumChangeRequest.addAssets(fastEnumeration)
        }, completionHandler: { success, error in
            guard let placeholder = placeholder else {
                completion?(nil)
                return
            }
            if success {
                let assets:PHFetchResult<PHAsset> = PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                let asset:PHAsset? = assets.firstObject
                completion?(asset)
            } else {
                print("save image to photo library", error?.localizedDescription)
                completion?(nil)
            }
        })
    }
}
