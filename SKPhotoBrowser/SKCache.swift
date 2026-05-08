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
        guard let data = dataForRequest(request) else {
            return nil
        }
        return UIImage(data: data)
    }

    open func dataForRequest(_ request: URLRequest) -> Data? {
        guard let cache = imageCache as? SKRequestResponseCacheable else {
            return nil
        }

        return cache.cachedResponseForRequest(request)?.data
    }

    open func setImageData(_ data: Data, response: URLResponse, request: URLRequest?) {
        guard let cache = imageCache as? SKRequestResponseCacheable, let request = request else {
            return
        }
        let cachedResponse = CachedURLResponse(response: response, data: data)
        cache.storeCachedResponse(cachedResponse, forRequest: request)
    }

    open func imageURLForKey(_ key: String) -> URL? {
        guard let cache = imageCache as? SKFileCacheable else {
            return nil
        }

        return cache.imageURLForKey(key)
    }

    open func dataURLForKey(_ key: String) -> URL? {
        guard let cache = imageCache as? SKFileCacheable else {
            return nil
        }

        return cache.dataURLForKey(key)
    }

    open func responseURLForRequest(_ request: URLRequest) -> URL? {
        guard let cache = imageCache as? SKFileCacheable else {
            return nil
        }

        return cache.responseURLForRequest(request)
    }
}

class SKDefaultImageCache: SKImageCacheable, SKDataCacheable, SKRequestResponseCacheable, SKFileCacheable {
    private let fileManager: FileManager
    let rootDirectory: URL
    let imageDirectory: URL
    let dataDirectory: URL
    let responseDirectory: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let storageDirectory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true)) ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        rootDirectory = storageDirectory.appendingPathComponent("SKPhotoBrowserCache", isDirectory: true)
        imageDirectory = rootDirectory.appendingPathComponent("Images", isDirectory: true)
        dataDirectory = rootDirectory.appendingPathComponent("Data", isDirectory: true)
        responseDirectory = rootDirectory.appendingPathComponent("Responses", isDirectory: true)
        createDirectoriesIfNeeded()
    }

    func imageForKey(_ key: String) -> UIImage? {
        guard let url = imageURLForKey(key),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        guard let data = image.pngData() ?? image.jpegData(compressionQuality: 1) else {
            return
        }
        try? data.write(to: imageFileURL(for: key), options: .atomic)
    }

    func removeImageForKey(_ key: String) {
        removeCachedFile(at: imageFileURL(for: key))
    }
    
    func removeAllImages() {
        removeContents(of: imageDirectory)
    }

    func dataForKey(_ key: String) -> Data? {
        guard let url = dataURLForKey(key) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    func setData(_ data: Data, forKey key: String) {
        try? data.write(to: dataFileURL(for: key), options: .atomic)
    }

    func removeDataForKey(_ key: String) {
        removeCachedFile(at: dataFileURL(for: key))
    }

    func removeAllData() {
        removeContents(of: dataDirectory)
    }

    func cachedResponseForRequest(_ request: URLRequest) -> CachedURLResponse? {
        guard let url = request.url,
              let responseURL = responseURLForRequest(request),
              let data = try? Data(contentsOf: responseURL) else {
            return nil
        }
        let response = URLResponse(
            url: url,
            mimeType: nil,
            expectedContentLength: data.count,
            textEncodingName: nil)
        return CachedURLResponse(response: response, data: data)
    }

    func storeCachedResponse(_ cachedResponse: CachedURLResponse, forRequest request: URLRequest) {
        try? cachedResponse.data.write(to: responseFileURL(for: request), options: .atomic)
    }

    func imageURLForKey(_ key: String) -> URL? {
        return existingURL(for: imageFileURL(for: key))
    }

    func dataURLForKey(_ key: String) -> URL? {
        return existingURL(for: dataFileURL(for: key))
    }

    func responseURLForRequest(_ request: URLRequest) -> URL? {
        return existingURL(for: responseFileURL(for: request))
    }

    private func createDirectoriesIfNeeded() {
        [rootDirectory, imageDirectory, dataDirectory, responseDirectory].forEach { directory in
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func imageFileURL(for key: String) -> URL {
        return imageDirectory
            .appendingPathComponent(cacheFileName(for: key, fallbackExtension: "png"))
    }

    private func dataFileURL(for key: String) -> URL {
        return dataDirectory
            .appendingPathComponent(cacheFileName(for: key, fallbackExtension: "data"))
    }

    private func responseFileURL(for request: URLRequest) -> URL {
        let key = request.url?.absoluteString ?? "\(request.hashValue)"
        return responseDirectory
            .appendingPathComponent(cacheFileName(for: key, fallbackExtension: "response"))
    }

    private func cacheFileName(for key: String, fallbackExtension: String) -> String {
        let component = lastPathComponent(for: key)
        if !component.isEmpty {
            return component
        }
        return "skphoto-cache.\(fallbackExtension)"
    }

    private func removeContents(of directory: URL) {
        guard let urls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        urls.forEach { try? fileManager.removeItem(at: $0) }
    }

    private func existingURL(for url: URL) -> URL? {
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private func removeCachedFile(at url: URL) {
        try? fileManager.removeItem(at: url)
    }

    private func lastPathComponent(for key: String) -> String {
        if let url = URL(string: key), !url.lastPathComponent.isEmpty, url.lastPathComponent != "/" {
            return safeFileName(url.lastPathComponent)
        }
        let component = URL(fileURLWithPath: key).lastPathComponent
        if !component.isEmpty, component != "/" {
            return safeFileName(component)
        }
        return ""
    }

    private func safeFileName(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:")
            .union(.newlines)
            .union(.controlCharacters)
        return filename.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}
