//
//  SKLocalPhoto.swift
//  SKPhotoBrowser
//
//  Created by Antoine Barrault on 13/04/2016.
//  Copyright © 2016 suzuki_keishi. All rights reserved.
//

import Photos
import UIKit

// MARK: - SKLocalPhoto
open class SKLocalPhoto: NSObject, SKPhotoProtocol, SKPhotoMediaProtocol {
    public var progress: Double = 1
    
    public var progressChanged: ((SKPhotoProtocol) -> Void)?
    
    open var underlyingImage: UIImage!
    open var photoURL: String!
    open var mediaType: SKPhotoMediaType = .image
    open var videoURL: URL?
    open var livePhotoImageURL: URL?
    open var livePhotoVideoURL: URL?
    open var coverImageURL: URL?
    @available(iOS 9.1, *)
    open var livePhoto: PHLivePhoto?
    open var contentMode: UIView.ContentMode = .scaleToFill
    open var shouldCachePhotoURLImage: Bool = false
    open var caption: String?
    open var index: Int = 0
    
    override init() {
        super.init()
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

    convenience init(videoURL: URL, holder: UIImage?, coverImageURL: URL? = nil) {
        self.init()
        mediaType = .video
        self.videoURL = videoURL
        self.coverImageURL = coverImageURL
        photoURL = videoURL.path
        underlyingImage = holder
    }

    convenience init(livePhotoImageURL: URL, pairedVideoURL: URL, holder: UIImage?, coverImageURL: URL? = nil) {
        self.init()
        mediaType = .livePhoto
        self.livePhotoImageURL = livePhotoImageURL
        self.livePhotoVideoURL = pairedVideoURL
        self.coverImageURL = coverImageURL ?? livePhotoImageURL
        photoURL = livePhotoImageURL.path
        underlyingImage = holder
    }
    
    open func checkCache() {}
    
    open func loadUnderlyingImageAndNotify() {
        switch mediaType {
        case .video:
            if videoURL == nil, let photoURL = photoURL {
                videoURL = URL(fileURLWithPath: photoURL)
            }
            loadUnderlyingImageComplete()
            return
        case .livePhoto:
            loadLivePhotoAndNotify()
            return
        case .image:
            break
        }
        
        if underlyingImage != nil && photoURL == nil {
            loadUnderlyingImageComplete()
        }
        
        if photoURL != nil {
            // Fetch Image
            if FileManager.default.fileExists(atPath: photoURL) {
                if let data = FileManager.default.contents(atPath: photoURL) {
                    self.loadUnderlyingImageComplete()
                    if let image = UIImage(data: data) {
                        self.underlyingImage = image
                        self.loadUnderlyingImageComplete()
                    }
                }
            }
        }
    }
    
    open func loadUnderlyingImageComplete() {
        NotificationCenter.default.post(name: Notification.Name(rawValue: SKPHOTO_LOADING_DID_END_NOTIFICATION), object: self)
    }
    
    // MARK: - class func
    open class func photoWithImageURL(_ url: String) -> SKLocalPhoto {
        return SKLocalPhoto(url: url)
    }
    
    open class func photoWithImageURL(_ url: String, holder: UIImage?) -> SKLocalPhoto {
        return SKLocalPhoto(url: url, holder: holder)
    }

    open class func photoWithVideoURL(_ url: String, holder: UIImage? = nil) -> SKLocalPhoto {
        return SKLocalPhoto(videoURL: URL(fileURLWithPath: url), holder: holder)
    }

    open class func photoWithVideoURL(_ url: String, coverImageURL: String) -> SKLocalPhoto {
        return SKLocalPhoto(videoURL: URL(fileURLWithPath: url), holder: nil, coverImageURL: URL(fileURLWithPath: coverImageURL))
    }

    open class func photoWithLivePhoto(_ imageURL: String, pairedVideoURL: String, holder: UIImage? = nil, coverImageURL: String? = nil) -> SKLocalPhoto {
        return SKLocalPhoto(
            livePhotoImageURL: URL(fileURLWithPath: imageURL),
            pairedVideoURL: URL(fileURLWithPath: pairedVideoURL),
            holder: holder,
            coverImageURL: coverImageURL.map { URL(fileURLWithPath: $0) })
    }
}

private extension SKLocalPhoto {
    func loadCoverImageIfNeeded() {
        guard underlyingImage == nil, let coverImageURL = coverImageURL, coverImageURL.isFileURL else {
            return
        }
        if let data = try? Data(contentsOf: coverImageURL), let image = UIImage(data: data) {
            underlyingImage = image
            progressChanged?(self)
        }
    }

    func loadLivePhotoAndNotify() {
        guard #available(iOS 9.1, *), let imageURL = livePhotoImageURL, let videoURL = livePhotoVideoURL else {
            loadUnderlyingImageComplete()
            return
        }
        if livePhoto != nil {
            loadUnderlyingImageComplete()
            return
        }

        PHLivePhoto.request(withResourceFileURLs: [imageURL, videoURL], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit) { [weak self] livePhoto, _ in
            guard let self = self else { return }
            self.livePhoto = livePhoto
            DispatchQueue.main.async {
                self.loadUnderlyingImageComplete()
            }
        }
    }
}
