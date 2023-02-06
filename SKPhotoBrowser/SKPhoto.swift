//
//  SKPhoto.swift
//  SKViewExample
//
//  Created by suzuki_keishi on 2015/10/01.
//  Copyright © 2015 suzuki_keishi. All rights reserved.
//

import UIKit
#if canImport(SKPhotoBrowserObjC)
import SKPhotoBrowserObjC
#endif

@objc public protocol SKPhotoProtocol: NSObjectProtocol {
    var index: Int { get set }
    var underlyingImage: UIImage! { get }
    var caption: String? { get }
    var contentMode: UIView.ContentMode { get set }
    
    var progress: Double { get set }
    var progressChanged: ((_ photo: SKPhotoProtocol) -> Void)?{ get set }
    
    func loadUnderlyingImageAndNotify()
    func checkCache()
}

// MARK: - SKPhoto
open class SKPhoto: NSObject, SKPhotoProtocol {
    open var index: Int = 0
    open var underlyingImage: UIImage!
    open var caption: String?
    open var contentMode: UIView.ContentMode = .scaleAspectFill
    open var progress: Double = 1
    open var shouldCachePhotoURLImage: Bool = false
    open var photoURL: String!
    open var progressChanged: ((SKPhotoProtocol) -> Void)?

    override init() {
        super.init()
    }
    
    convenience init(image: UIImage) {
        self.init()
        underlyingImage = image
    }
    
    convenience init(url: String) {
        self.init()
        photoURL = url
    }
    
    convenience init(url: String, holder: UIImage?) {
        self.init()
        photoURL = url
        underlyingImage = holder
    }
    
    open func checkCache() {
        guard let photoURL = photoURL else {
            return
        }
        guard shouldCachePhotoURLImage else {
            return
        }
        
        if SKCache.sharedCache.imageCache is SKRequestResponseCacheable {
            let request = URLRequest(url: URL(string: photoURL)!)
            if let img = SKCache.sharedCache.imageForRequest(request) {
                underlyingImage = img
            }
        } else {
            if let img = SKCache.sharedCache.imageForKey(photoURL) {
                underlyingImage = img
            }
        }
    }
    
    open func loadUnderlyingImageAndNotify() {
        guard photoURL != nil, let URL = URL(string: photoURL) else { return }
        
        if self.shouldCachePhotoURLImage {
            if SKCache.sharedCache.imageCache is SKRequestResponseCacheable {
                let request = URLRequest(url: URL)
                if let img = SKCache.sharedCache.imageForRequest(request) {
                    DispatchQueue.main.async {
                        self.underlyingImage = img
                        self.loadUnderlyingImageComplete()
                    }
                    return
                }
            } else {
                if let img = SKCache.sharedCache.imageForKey(photoURL) {
                    DispatchQueue.main.async {
                        self.underlyingImage = img
                        self.loadUnderlyingImageComplete()
                    }
                    return
                }
            }
        }
        progress = 0
        // Fetch Image
        let session = URLSession(configuration: SKPhotoBrowserOptions.sessionConfiguration, delegate: self, delegateQueue: OperationQueue())
            var task: URLSessionTask?
        task = session.downloadTask(with: URL)
        /*
            task = session.dataTask(with: URL, completionHandler: { [weak self] (data, response, error) in
                guard let self = self else { return }
                defer { session.finishTasksAndInvalidate() }

                guard error == nil else {
                    DispatchQueue.main.async {
                        self.loadUnderlyingImageComplete()
                    }
                    return
                }

                if let data = data, let response = response, let image = UIImage.animatedImage(withAnimatedGIFData: data) {
                    if self.shouldCachePhotoURLImage {
                        if SKCache.sharedCache.imageCache is SKRequestResponseCacheable {
                            SKCache.sharedCache.setImageData(data, response: response, request: task?.originalRequest)
                        } else {
                            SKCache.sharedCache.setImage(image, forKey: self.photoURL)
                        }
                    }
                    DispatchQueue.main.async {
                        self.underlyingImage = image
                        self.loadUnderlyingImageComplete()
                    }
                }
                
            })
         */
            task?.resume()
    }

    open func loadUnderlyingImageComplete() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION), object: self)
        progress = 1
        progressChanged?(self)
    }
    
}


extension SKPhoto: URLSessionDelegate, URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64){
        progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressChanged?(self)
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL){
        defer { session.finishTasksAndInvalidate() }
        guard let data = try? Data(contentsOf: location),
        let image = UIImage.animatedImage(withAnimatedGIFData: data) else{
            DispatchQueue.main.async {
                self.loadUnderlyingImageComplete()
            }
            return
        }
        if self.shouldCachePhotoURLImage {
            SKCache.sharedCache.setImage(image, forKey: self.photoURL)
        }
        DispatchQueue.main.async {
            self.underlyingImage = image
            self.loadUnderlyingImageComplete()
        }
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DispatchQueue.main.async {
            self.loadUnderlyingImageComplete()
        }
    }
}

// MARK: - Static Function

extension SKPhoto {
    public static func photoWithImage(_ image: UIImage) -> SKPhoto {
        return SKPhoto(image: image)
    }
    
    public static func photoWithImageURL(_ url: String) -> SKPhoto {
        return SKPhoto(url: url)
    }
    
    public static func photoWithImageURL(_ url: String, holder: UIImage?) -> SKPhoto {
        return SKPhoto(url: url, holder: holder)
    }
}
