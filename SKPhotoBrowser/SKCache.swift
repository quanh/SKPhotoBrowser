//
//  SKCache.swift
//  SKPhotoBrowser
//
//  Created by Kevin Wolkober on 6/13/16.
//  Copyright © 2016 suzuki_keishi. All rights reserved.
//

import UIKit

open class SKCache {
    public static let sharedCache = SKCache()
    open var imageCache: SKCacheable

    init() {
        self.imageCache = SKDefaultImageCache()
    }

    open func imageForKey(_ key: String) -> UIImage? {
        guard let cache = imageCache as? SKImageCacheable else {
            return nil
        }
        
        return cache.imageForKey(key)
    }

    open func setImage(_ image: UIImage, forKey key: String) {
        guard let cache = imageCache as? SKImageCacheable else {
            return
        }
        
        cache.setImage(image, forKey: key)
    }

    open func removeImageForKey(_ key: String) {
        guard let cache = imageCache as? SKImageCacheable else {
            return
        }
        
        cache.removeImageForKey(key)
    }
    
    open func removeAllImages() {
        guard let cache = imageCache as? SKImageCacheable else {
            return
        }
        
        cache.removeAllImages()
    }

    open func dataForKey(_ key: String) -> Data? {
        guard let cache = imageCache as? SKDataCacheable else {
            return nil
        }

        return cache.dataForKey(key)
    }

    open func setData(_ data: Data, forKey key: String) {
        guard let cache = imageCache as? SKDataCacheable else {
            return
        }

        cache.setData(data, forKey: key)
    }

    open func removeDataForKey(_ key: String) {
        guard let cache = imageCache as? SKDataCacheable else {
            return
        }

        cache.removeDataForKey(key)
    }

    open func removeAllData() {
        guard let cache = imageCache as? SKDataCacheable else {
            return
        }

        cache.removeAllData()
    }

    open func imageForRequest(_ request: URLRequest) -> UIImage? {
        guard let cache = imageCache as? SKRequestResponseCacheable else {
            return nil
        }
        
        if let response = cache.cachedResponseForRequest(request) {
            return UIImage(data: response.data)
        }
        return nil
    }

    open func setImageData(_ data: Data, response: URLResponse, request: URLRequest?) {
        guard let cache = imageCache as? SKRequestResponseCacheable, let request = request else {
            return
        }
        let cachedResponse = CachedURLResponse(response: response, data: data)
        cache.storeCachedResponse(cachedResponse, forRequest: request)
    }
}

class SKDefaultImageCache: SKImageCacheable, SKDataCacheable {
    var cache: NSCache<AnyObject, AnyObject>
    var dataCache: NSCache<AnyObject, AnyObject>

    init() {
        cache = NSCache()
        dataCache = NSCache()
    }

    func imageForKey(_ key: String) -> UIImage? {
        return cache.object(forKey: key as AnyObject) as? UIImage
    }

    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as AnyObject)
    }

    func removeImageForKey(_ key: String) {
        cache.removeObject(forKey: key as AnyObject)
    }
    
    func removeAllImages() {
        cache.removeAllObjects()
    }

    func dataForKey(_ key: String) -> Data? {
        return dataCache.object(forKey: key as AnyObject) as? Data
    }

    func setData(_ data: Data, forKey key: String) {
        dataCache.setObject(data as AnyObject, forKey: key as AnyObject)
    }

    func removeDataForKey(_ key: String) {
        dataCache.removeObject(forKey: key as AnyObject)
    }

    func removeAllData() {
        dataCache.removeAllObjects()
    }
}
