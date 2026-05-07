//
//  SKPhoto.swift
//  SKViewExample
//
//  Created by suzuki_keishi on 2015/10/01.
//  Copyright © 2015 suzuki_keishi. All rights reserved.
//

import AVFoundation
import ImageIO
import MobileCoreServices
import Photos
import UIKit
#if canImport(SKPhotoBrowserObjC)
import SKPhotoBrowserObjC
#endif

@objc public enum SKPhotoMediaType: Int {
    case image
    case livePhoto
    case video
}

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

@objc public protocol SKPhotoMediaProtocol: NSObjectProtocol {
    var mediaType: SKPhotoMediaType { get }
    var videoURL: URL? { get }
    var livePhotoImageURL: URL? { get }
    var livePhotoVideoURL: URL? { get }
    var coverImageURL: URL? { get }

    @available(iOS 9.1, *)
    var livePhoto: PHLivePhoto? { get }
}

// MARK: - SKPhoto
open class SKPhoto: NSObject, SKPhotoProtocol, SKPhotoMediaProtocol {
    open var index: Int = 0
    open var underlyingImage: UIImage!
    open var caption: String?
    open var contentMode: UIView.ContentMode = .scaleAspectFill
    open var progress: Double = 1
    open var shouldCachePhotoURLImage: Bool = false
    open var photoURL: String!
    open var mediaType: SKPhotoMediaType = .image
    open var videoURL: URL?
    open var livePhotoImageURL: URL?
    open var livePhotoVideoURL: URL?
    open var coverImageURL: URL?
    @available(iOS 9.1, *)
    open var livePhoto: PHLivePhoto?
    open var progressChanged: ((SKPhotoProtocol) -> Void)?
    private var downloadKinds: [Int: DownloadKind] = [:]
    private var livePhotoResourceData: [DownloadKind: Data] = [:]
    private var livePhotoProgress: [DownloadKind: Double] = [:]

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

    convenience init(videoURL: URL, holder: UIImage?, coverImageURL: URL? = nil) {
        self.init()
        self.mediaType = .video
        self.photoURL = videoURL.absoluteString
        self.videoURL = videoURL
        self.coverImageURL = coverImageURL
        self.underlyingImage = holder
    }

    convenience init(livePhotoImageURL: URL, pairedVideoURL: URL, holder: UIImage?, coverImageURL: URL? = nil) {
        self.init()
        self.mediaType = .livePhoto
        self.photoURL = livePhotoImageURL.absoluteString
        self.livePhotoImageURL = livePhotoImageURL
        self.livePhotoVideoURL = pairedVideoURL
        self.coverImageURL = coverImageURL ?? livePhotoImageURL
        self.underlyingImage = holder
    }
    
    open func checkCache() {
        if mediaType != .image {
            checkMediaCache()
            return
        }

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
        switch mediaType {
        case .video:
            loadVideoAndNotify()
            return
        case .livePhoto:
            loadLivePhotoAndNotify()
            return
        case .image:
            break
        }

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
        progressChanged?(self)
        // Fetch Image
        let session = makeDownloadSession()
        var task: URLSessionTask?
        task = session.downloadTask(with: URL)
        if let task = task {
            downloadKinds[task.taskIdentifier] = .image
        }
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

private enum DownloadKind {
    case image
    case cover
    case video
    case livePhotoImage
    case livePhotoVideo
}

private extension SKPhoto {
    func notifyProgressChanged() {
        DispatchQueue.main.async {
            self.progressChanged?(self)
        }
    }

    func startDownload(_ url: URL, kind: DownloadKind, session: URLSession? = nil) {
        let downloadSession = session ?? makeDownloadSession()
        let task = downloadSession.downloadTask(with: url)
        downloadKinds[task.taskIdentifier] = kind
        task.resume()
    }

    func makeDownloadSession() -> URLSession {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return URLSession(configuration: SKPhotoBrowserOptions.sessionConfiguration, delegate: self, delegateQueue: queue)
    }

    func loadCoverImageIfNeeded() {
        guard underlyingImage == nil, let coverImageURL = coverImageURL else {
            return
        }

        let key = coverImageURL.absoluteString
        if shouldCachePhotoURLImage, let cachedImage = SKCache.sharedCache.imageForKey(key) {
            underlyingImage = cachedImage
            notifyProgressChanged()
            return
        }

        if coverImageURL.isFileURL {
            if let data = try? Data(contentsOf: coverImageURL), let image = UIImage(data: data) {
                underlyingImage = image
                notifyProgressChanged()
            }
            return
        }

        startDownload(coverImageURL, kind: .cover)
    }

    func checkMediaCache() {
        guard shouldCachePhotoURLImage else { return }

        switch mediaType {
        case .video:
            guard let key = photoURL, let data = SKCache.sharedCache.dataForKey(key) else { return }
            videoURL = writeCachedData(data, cacheKey: key, fileExtension: videoURL?.pathExtension)
        case .livePhoto:
            guard let imageURL = livePhotoImageURL, let videoURL = livePhotoVideoURL,
                  SKCache.sharedCache.dataForKey(imageURL.absoluteString) != nil,
                  SKCache.sharedCache.dataForKey(videoURL.absoluteString) != nil else {
                return
            }
            prepareLivePhotoFromCachedResources()
        case .image:
            return
        }
    }

    func loadVideoAndNotify() {
        guard let sourceURL = videoURL ?? urlFromString(photoURL) else {
            loadUnderlyingImageComplete()
            return
        }
        loadCoverImageIfNeeded()

        if sourceURL.isFileURL {
            videoURL = sourceURL
            loadUnderlyingImageComplete()
            return
        }

        let key = sourceURL.absoluteString
        if shouldCachePhotoURLImage, let data = SKCache.sharedCache.dataForKey(key) {
            videoURL = writeCachedData(data, cacheKey: key, fileExtension: sourceURL.pathExtension)
            loadUnderlyingImageComplete()
            return
        }

        progress = 0
        progressChanged?(self)
        startDownload(sourceURL, kind: .video)
    }

    func loadLivePhotoAndNotify() {
        guard #available(iOS 9.1, *) else {
            loadUnderlyingImageComplete()
            return
        }
        if livePhoto != nil {
            loadUnderlyingImageComplete()
            return
        }

        guard let imageURL = livePhotoImageURL, let videoURL = livePhotoVideoURL else {
            loadUnderlyingImageComplete()
            return
        }
        loadCoverImageIfNeeded()

        if imageURL.isFileURL && videoURL.isFileURL {
            requestLivePhoto(imageURL: imageURL, videoURL: videoURL)
            return
        }

        if shouldCachePhotoURLImage,
           SKCache.sharedCache.dataForKey(imageURL.absoluteString) != nil,
           SKCache.sharedCache.dataForKey(videoURL.absoluteString) != nil {
            prepareLivePhotoFromCachedResources()
            return
        }

        progress = 0
        progressChanged?(self)
        livePhotoResourceData.removeAll()
        livePhotoProgress = [.livePhotoImage: 0, .livePhotoVideo: 0]
        let session = makeDownloadSession()
        startDownload(imageURL, kind: .livePhotoImage, session: session)
        startDownload(videoURL, kind: .livePhotoVideo, session: session)
    }

    @available(iOS 9.1, *)
    func requestLivePhoto(imageURL: URL, videoURL: URL) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let livePhoto = try await SKLivePhotoManager.shared.buildLivePhoto(
                    coverUrl: imageURL.absoluteString,
                    videoUrl: videoURL.absoluteString)
                await MainActor.run {
                    self.livePhoto = livePhoto
                    self.loadUnderlyingImageComplete()
                }
            } catch {
                await MainActor.run {
                    PHLivePhoto.request(
                        withResourceFileURLs: [imageURL, videoURL],
                        placeholderImage: self.underlyingImage,
                        targetSize: .zero,
                        contentMode: .aspectFit) { livePhoto, _ in
                            self.livePhoto = livePhoto
                            self.loadUnderlyingImageComplete()
                        }
                }
            }
        }
    }
}

private enum SKLivePhotosError: Error {
    case noCachesDirectory
}

private enum SKLivePhotosAssembleError: Error {
    case addPhotoIdentifierFailed
    case createDestinationImageFailed
    case writingVideoFailed
    case writingAudioFailed
    case requestFailed
    case loadTracksFailed
}

private actor SKLivePhotoManager {
    static let shared = SKLivePhotoManager()

    private var livePhotoCache: [String: PHLivePhoto] = [:]

    @available(iOS 9.1, *)
    func buildLivePhoto(coverUrl: String, videoUrl: String) async throws -> PHLivePhoto {
        if let livePhoto = livePhotoCache[coverUrl] {
            return livePhoto
        }

        let coverImageUrl = url(from: coverUrl)
        let videoUrl = url(from: videoUrl)
        let result = try await SKLivePhotos.shared.assemble(photoURL: coverImageUrl, videoURL: videoUrl)
        livePhotoCache[coverUrl] = result.0
        return result.0
    }

    private func url(from string: String) -> URL {
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        return URL(fileURLWithPath: string)
    }
}

private actor SKLivePhotos {
    static let shared = SKLivePhotos()

    @available(iOS 9.1, *)
    func assemble(photoURL: URL, videoURL: URL, progress: ((Float) -> Void)? = nil) async throws -> (PHLivePhoto, (URL, URL)) {
        let cacheDirectory = try cachesDirectory()
        let identifier = UUID().uuidString
        let pairedPhotoURL = try addIdentifier(
            identifier,
            fromPhotoURL: photoURL,
            to: cacheDirectory.appendingPathComponent(identifier).appendingPathExtension("jpg"))
        let pairedVideoURL = try await addIdentifier(
            identifier,
            fromVideoURL: videoURL,
            to: cacheDirectory.appendingPathComponent(identifier).appendingPathExtension("mov"),
            progress: progress)

        let livePhoto = try await withCheckedThrowingContinuation({ continuation in
            PHLivePhoto.request(
                withResourceFileURLs: [pairedPhotoURL, pairedVideoURL],
                placeholderImage: nil,
                targetSize: .zero,
                contentMode: .aspectFill) { livePhoto, info in
                    if let isDegraded = info[PHLivePhotoInfoIsDegradedKey] as? Bool, isDegraded {
                        return
                    }
                    if let livePhoto {
                        continuation.resume(returning: livePhoto)
                    } else {
                        continuation.resume(throwing: SKLivePhotosAssembleError.requestFailed)
                    }
                }
        })
        return (livePhoto, (pairedPhotoURL, pairedVideoURL))
    }

    private func addIdentifier(_ identifier: String, fromPhotoURL photoURL: URL, to destinationURL: URL) throws -> URL {
        guard let imageSource = CGImageSourceCreateWithURL(photoURL as CFURL, nil),
              let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
              var imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [AnyHashable : Any] else {
            throw SKLivePhotosAssembleError.addPhotoIdentifierFailed
        }
        let identifierInfo = ["17" : identifier]
        imageProperties[kCGImagePropertyMakerAppleDictionary] = identifierInfo
        guard let imageDestination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypeJPEG, 1, nil) else {
            throw SKLivePhotosAssembleError.createDestinationImageFailed
        }
        CGImageDestinationAddImage(imageDestination, imageRef, imageProperties as CFDictionary)
        if CGImageDestinationFinalize(imageDestination) {
            return destinationURL
        } else {
            throw SKLivePhotosAssembleError.createDestinationImageFailed
        }
    }

    private func addIdentifier(
        _ identifier: String,
        fromVideoURL videoURL: URL,
        to destinationURL: URL,
        progress: ((Float) -> Void)? = nil
    ) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        let videoReader = try AVAssetReader(asset: asset)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw SKLivePhotosAssembleError.loadTracksFailed
        }
        let videoReaderOutputSettings: [String : Any] = [kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA]
        let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderOutputSettings)
        videoReader.add(videoReaderOutput)

        let audioReader = try AVAssetReader(asset: asset)
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw SKLivePhotosAssembleError.loadTracksFailed
        }
        let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
        audioReader.add(audioReaderOutput)

        let assetWriter = try AVAssetWriter(outputURL: destinationURL, fileType: .mov)

        let videoWriterInputOutputSettings: [String : Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: try await videoTrack.load(.naturalSize).width,
            AVVideoHeightKey: try await videoTrack.load(.naturalSize).height]
        let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoWriterInputOutputSettings)
        videoWriterInput.transform = try await videoTrack.load(.preferredTransform)
        videoWriterInput.expectsMediaDataInRealTime = true
        assetWriter.add(videoWriterInput)

        let audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
        audioWriterInput.expectsMediaDataInRealTime = false
        assetWriter.add(audioWriterInput)

        let identifierMetadata = metadataItem(for: identifier)
        let stillImageTimeMetadataAdaptor = stillImageTimeMetadataAdaptor()
        assetWriter.metadata = [identifierMetadata]
        assetWriter.add(stillImageTimeMetadataAdaptor.assetWriterInput)

        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)

        let frameCount = try await asset.frameCount()
        let stillImagePercent: Float = 0.5
        await stillImageTimeMetadataAdaptor.append(
            AVTimedMetadataGroup(
                items: [stillImageTimeMetadataItem()],
                timeRange: try asset.makeStillImageTimeRange(percent: stillImagePercent, inFrameCount: frameCount)))

        async let writingVideoFinished: Bool = withCheckedThrowingContinuation { continuation in
            Task {
                videoReader.startReading()
                var currentFrameCount = 0
                videoWriterInput.requestMediaDataWhenReady(on: DispatchQueue(label: "videoWriterInputQueue")) {
                    while videoWriterInput.isReadyForMoreMediaData {
                        if let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() {
                            currentFrameCount += 1
                            if let progress {
                                let progressValue = min(Float(currentFrameCount) / Float(frameCount), 1.0)
                                Task { @MainActor in
                                    progress(progressValue)
                                }
                            }
                            if !videoWriterInput.append(sampleBuffer) {
                                videoReader.cancelReading()
                                continuation.resume(throwing: SKLivePhotosAssembleError.writingVideoFailed)
                                return
                            }
                        } else {
                            videoWriterInput.markAsFinished()
                            continuation.resume(returning: true)
                            return
                        }
                    }
                }
            }
        }

        async let writingAudioFinished: Bool = withCheckedThrowingContinuation { continuation in
            Task {
                audioReader.startReading()
                audioWriterInput.requestMediaDataWhenReady(on: DispatchQueue(label: "audioWriterInputQueue")) {
                    while audioWriterInput.isReadyForMoreMediaData {
                        if let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() {
                            if !audioWriterInput.append(sampleBuffer) {
                                audioReader.cancelReading()
                                continuation.resume(throwing: SKLivePhotosAssembleError.writingAudioFailed)
                                return
                            }
                        } else {
                            audioWriterInput.markAsFinished()
                            continuation.resume(returning: true)
                            return
                        }
                    }
                }
            }
        }

        await (_, _) = try (writingVideoFinished, writingAudioFinished)
        await assetWriter.finishWriting()
        return destinationURL
    }

    private func metadataItem(for identifier: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.keySpace = AVMetadataKeySpace.quickTimeMetadata
        item.dataType = "com.apple.metadata.datatype.UTF-8"
        item.key = AVMetadataKey.quickTimeMetadataKeyContentIdentifier as any NSCopying & NSObjectProtocol
        item.value = identifier as any NSCopying & NSObjectProtocol
        return item
    }

    private func stillImageTimeMetadataAdaptor() -> AVAssetWriterInputMetadataAdaptor {
        let quickTimeMetadataKeySpace = AVMetadataKeySpace.quickTimeMetadata.rawValue
        let stillImageTimeKey = "com.apple.quicktime.still-image-time"
        let spec: [NSString : Any] = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as NSString: "\(quickTimeMetadataKeySpace)/\(stillImageTimeKey)",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as NSString: kCMMetadataBaseDataType_SInt8]
        var desc: CMFormatDescription?
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [spec] as CFArray,
            formatDescriptionOut: &desc)
        let input = AVAssetWriterInput(
            mediaType: .metadata,
            outputSettings: nil,
            sourceFormatHint: desc)
        return AVAssetWriterInputMetadataAdaptor(assetWriterInput: input)
    }

    private func stillImageTimeMetadataItem() -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.key = "com.apple.quicktime.still-image-time" as any NSCopying & NSObjectProtocol
        item.keySpace = AVMetadataKeySpace.quickTimeMetadata
        item.value = 0 as any NSCopying & NSObjectProtocol
        item.dataType = kCMMetadataBaseDataType_SInt8 as String
        return item
    }

    private func cachesDirectory(component: String = "SKLivePhotos") throws -> URL {
        if let cachesDirectoryURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let cachesDirectory = cachesDirectoryURL.appendingPathComponent(component, isDirectory: true)
            if !FileManager.default.fileExists(atPath: cachesDirectory.path) {
                try? FileManager.default.createDirectory(at: cachesDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            return cachesDirectory
        }
        throw SKLivePhotosError.noCachesDirectory
    }
}

private extension AVAsset {
    func frameCount(exact: Bool = false) async throws -> Int {
        let videoReader = try AVAssetReader(asset: self)
        guard let videoTrack = try await self.loadTracks(withMediaType: .video).first else {
            return 0
        }
        if !exact {
            async let duration = CMTimeGetSeconds(self.load(.duration))
            async let nominalFrameRate = Float64(videoTrack.load(.nominalFrameRate))
            return try await Int(duration * nominalFrameRate)
        }
        let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        videoReader.add(videoReaderOutput)
        videoReader.startReading()
        var frameCount = 0
        while videoReaderOutput.copyNextSampleBuffer() != nil {
            frameCount += 1
        }
        videoReader.cancelReading()
        return frameCount
    }

    func makeStillImageTimeRange(percent: Float, inFrameCount: Int = 0) async throws -> CMTimeRange {
        var time = try await self.load(.duration)
        var frameCount = inFrameCount
        if frameCount == 0 {
            frameCount = try await self.frameCount(exact: true)
        }
        let duration = Int64(Float(time.value) / Float(frameCount))
        time.value = Int64(Float(time.value) * percent)
        return CMTimeRangeMake(start: time, duration: CMTimeMake(value: duration, timescale: time.timescale))
    }
}

private extension SKPhoto {
    func prepareLivePhotoFromCachedResources() {
        guard #available(iOS 9.1, *),
              let imageURL = livePhotoImageURL,
              let videoURL = livePhotoVideoURL,
              let imageData = SKCache.sharedCache.dataForKey(imageURL.absoluteString),
              let videoData = SKCache.sharedCache.dataForKey(videoURL.absoluteString) else {
            loadUnderlyingImageComplete()
            return
        }

        let cachedImageURL = writeCachedData(imageData, cacheKey: imageURL.absoluteString, fileExtension: imageURL.pathExtension)
        let cachedVideoURL = writeCachedData(videoData, cacheKey: videoURL.absoluteString, fileExtension: videoURL.pathExtension)
        requestLivePhoto(imageURL: cachedImageURL, videoURL: cachedVideoURL)
    }

    func writeCachedData(_ data: Data, cacheKey: String, fileExtension: String?) -> URL {
        let ext = (fileExtension?.isEmpty == false ? fileExtension! : "tmp")
        let filename = "\(abs(cacheKey.hashValue)).\(ext)"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        return url
    }

    func urlFromString(_ string: String?) -> URL? {
        guard let string = string else { return nil }
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        return URL(fileURLWithPath: string)
    }
}


extension SKPhoto: URLSessionDelegate, URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64){
        guard totalBytesExpectedToWrite > 0 else {
            return
        }
        let taskProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        switch downloadKinds[downloadTask.taskIdentifier] ?? .image {
        case .cover:
            return
        case .livePhotoImage, .livePhotoVideo:
            if let kind = downloadKinds[downloadTask.taskIdentifier] {
                livePhotoProgress[kind] = taskProgress
                let imageProgress = livePhotoProgress[.livePhotoImage] ?? 0
                let videoProgress = livePhotoProgress[.livePhotoVideo] ?? 0
                progress = (imageProgress + videoProgress) / 2
            }
        case .image, .video:
            progress = taskProgress
        }
        notifyProgressChanged()
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL){
        let kind = downloadKinds[downloadTask.taskIdentifier] ?? .image
        downloadKinds[downloadTask.taskIdentifier] = nil

        guard let data = try? Data(contentsOf: location) else {
            session.finishTasksAndInvalidate()
            if kind != .cover {
                DispatchQueue.main.async {
                    self.loadUnderlyingImageComplete()
                }
            }
            return
        }

        switch kind {
        case .cover:
            handleDownloadedCover(data, downloadTask: downloadTask)
            session.finishTasksAndInvalidate()
        case .video:
            handleDownloadedVideo(data, downloadTask: downloadTask)
            session.finishTasksAndInvalidate()
        case .livePhotoImage, .livePhotoVideo:
            handleDownloadedLivePhotoResource(data, kind: kind, session: session)
        case .image:
            handleDownloadedImage(data)
            session.finishTasksAndInvalidate()
        }
    }

    private func handleDownloadedCover(_ data: Data, downloadTask: URLSessionDownloadTask) {
        guard let image = UIImage(data: data) else {
            return
        }
        if shouldCachePhotoURLImage, let key = downloadTask.originalRequest?.url?.absoluteString {
            SKCache.sharedCache.setImage(image, forKey: key)
        }
        DispatchQueue.main.async {
            self.underlyingImage = image
            self.progressChanged?(self)
        }
    }

    private func handleDownloadedVideo(_ data: Data, downloadTask: URLSessionDownloadTask) {
        let sourceURL = downloadTask.originalRequest?.url
        let key = sourceURL?.absoluteString ?? photoURL ?? ""
        if shouldCachePhotoURLImage {
            SKCache.sharedCache.setData(data, forKey: key)
        }
        videoURL = writeCachedData(data, cacheKey: key, fileExtension: sourceURL?.pathExtension)
        DispatchQueue.main.async {
            self.loadUnderlyingImageComplete()
        }
    }

    private func handleDownloadedLivePhotoResource(_ data: Data, kind: DownloadKind, session: URLSession) {
        livePhotoResourceData[kind] = data
        guard let imageURL = livePhotoImageURL,
              let videoURL = livePhotoVideoURL,
              let imageData = livePhotoResourceData[.livePhotoImage],
              let videoData = livePhotoResourceData[.livePhotoVideo],
              #available(iOS 9.1, *) else {
            return
        }

        if shouldCachePhotoURLImage {
            SKCache.sharedCache.setData(imageData, forKey: imageURL.absoluteString)
            SKCache.sharedCache.setData(videoData, forKey: videoURL.absoluteString)
        }
        let cachedImageURL = writeCachedData(imageData, cacheKey: imageURL.absoluteString, fileExtension: imageURL.pathExtension)
        let cachedVideoURL = writeCachedData(videoData, cacheKey: videoURL.absoluteString, fileExtension: videoURL.pathExtension)
        session.finishTasksAndInvalidate()
        requestLivePhoto(imageURL: cachedImageURL, videoURL: cachedVideoURL)
    }

    private func handleDownloadedImage(_ data: Data) {
        guard let image = UIImage.animatedImage(withAnimatedGIFData: data) else {
            DispatchQueue.main.async {
                self.loadUnderlyingImageComplete()
            }
            return
        }
        if shouldCachePhotoURLImage {
            SKCache.sharedCache.setImage(image, forKey: photoURL)
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

    public static func photoWithVideoURL(_ url: String, holder: UIImage? = nil, coverImageURL: String? = nil) -> SKPhoto {
        return SKPhoto(videoURL: mediaURL(from: url), holder: holder, coverImageURL: coverImageURL.map(mediaURL))
    }

    public static func photoWithVideoURL(_ url: String, coverImageURL: String) -> SKPhoto {
        return SKPhoto(videoURL: mediaURL(from: url), holder: nil, coverImageURL: mediaURL(from: coverImageURL))
    }

    public static func photoWithLivePhoto(_ imageURL: String, pairedVideoURL: String, holder: UIImage? = nil, coverImageURL: String? = nil) -> SKPhoto {
        return SKPhoto(
            livePhotoImageURL: mediaURL(from: imageURL),
            pairedVideoURL: mediaURL(from: pairedVideoURL),
            holder: holder,
            coverImageURL: coverImageURL.map(mediaURL))
    }

    private static func mediaURL(from string: String) -> URL {
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        return URL(fileURLWithPath: string)
    }
}
