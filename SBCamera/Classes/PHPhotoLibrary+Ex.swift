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
import SwiftPermissionManager

public enum SBCameraSavedError: Error {
    case notFoundAlbum, notCreateAlbum(error: Error?)
    case notCreateRequestForAsset, notCreateRequestForChanges
    
    case notSavedError(error: Error?), notFoundAsset
    case notPermission
    
    case notCreateImageData
}

public extension PHPhotoLibrary {
    typealias PHAssetCompletion = (Result<PHAsset, SBCameraSavedError>) -> ()
    typealias PHAssetCollectionCompletion = (Result<PHAssetCollection, SBCameraSavedError>) -> ()
    
    public enum SaveItem {
        case image(image: UIImage)
        case imageUrl(url: URL)
        case video(url: URL)
    }
    
    // MARK: - Public
    // if albumName == nil, wiil be get first album from library
    func save(item: SaveItem, albumName: String?, date: Date = Date(), location: CLLocation? = nil, completion: @escaping PHAssetCompletion) {
        PermissionManager().checkPhotoLibraryPermission(request: .readWrite) { [weak self] (result) in
            switch result {
            case .success:
                self?.getAlbum(name: albumName) { [weak self] album in
                    switch album {
                    case let .success(album):
                        self?.save(item: item, album: album, date: date, location: location, completion: completion)
                    case let .failure(error):
                        completion(.failure(.notSavedError(error: error)))
                    }
                }
            case let.failure(error):
                print("permission error - \(error.localizedDescription)")
                completion(.failure(.notPermission))
            }
        }
    }
    
    // MARK: - Private
    
    /// finds or creates an album
    private func getAlbum(name: String?, completion: @escaping PHAssetCollectionCompletion) {
        if let album = findAlbum(name: name) {
            completion(.success(album))
        } else if let name = name {
            createAlbum(name: name, completion: completion)
        } else {
            completion(.failure(.notFoundAlbum))
        }
    }
    
    fileprivate func findAlbum(name: String?) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        if let name = name {
            fetchOptions.predicate = NSPredicate(format: "title = %@", name)
        }
        
        guard let album = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions).firstObject else {
            return nil
        }

        return album
    }
    
    fileprivate func createAlbum(name: String, completion: @escaping PHAssetCollectionCompletion) {
        var placeholder: PHObjectPlaceholder?
        
        performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = request.placeholderForCreatedAssetCollection
            
        } completionHandler: { (success, error) in
            guard success, error == nil else {
                completion(.failure(.notCreateAlbum(error: error)))
                return
            }
            
            guard let placeholder = placeholder,
                  let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil).firstObject else {
                completion(.failure(.notFoundAlbum))
                return
            }
            
            completion(.success(collection))
        }
    }
    
    fileprivate func createAssetRequest(item: SaveItem) -> PHAssetChangeRequest? {
        switch item {
        case let .image(image):
            return PHAssetChangeRequest.creationRequestForAsset(from: image)
        case let .imageUrl(url):
            return PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
        case let .video(url):
            return PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }

    fileprivate func save(item: SaveItem, album: PHAssetCollection, date: Date = Date(), location: CLLocation? = nil, completion: @escaping PHAssetCompletion) {
        var placeholder: PHObjectPlaceholder?
        
        performChanges { [weak self] in
            guard let createAssetRequest = self?.createAssetRequest(item: item) else {
                completion(.failure(.notCreateRequestForAsset))
                return
            }

            createAssetRequest.creationDate = date
            createAssetRequest.location = location
            
            guard let changedRequest = PHAssetCollectionChangeRequest(for: album),
                  let placeholderAsset = createAssetRequest.placeholderForCreatedAsset else {
                completion(.failure(.notCreateRequestForChanges))
                return
            }
            
            placeholder = placeholderAsset
            changedRequest.addAssets(NSArray(array: [placeholderAsset]))
            
        } completionHandler: { (success, error) in
            guard success, error == nil else {
                completion(.failure(.notSavedError(error: error)))
                return
            }
            
            guard let placeholder = placeholder,
                  let asset = PHAsset.fetchAssets(withLocalIdentifiers: [placeholder.localIdentifier], options: nil).firstObject else {
                completion(.failure(.notFoundAsset))
                return
            }
            
            completion(.success(asset))
        }
    }
}
