//
//  SKZoomingScrollView.swift
//  SKViewExample
//
//  Created by suzuki_keihsi on 2015/10/01.
//  Copyright © 2015 suzuki_keishi. All rights reserved.
//

import AVKit
import PhotosUI
import UIKit

open class SKZoomingScrollView: UIScrollView {
    var captionView: SKCaptionView?
    var photo: SKPhotoProtocol? {
        didSet {
            imageView.image = nil
            photo?.progressChanged = {[weak self] p in
                DispatchQueue.main.async {
                    guard let self = self, self.photo === p else {
                        return
                    }
                    self.indicatorView.progress = p.progress
                    self.updatePlayButton()
                    guard (p as? SKPhotoMediaProtocol)?.mediaType ?? .image == .image else {
                        return
                    }
                    if self.playerLayer == nil,
                       self.livePhotoView == nil,
                       let image = p.underlyingImage {
                        self.displayImage(image)
                    }
                }
            }
            if let _ = photo?.underlyingImage,
               (photo as? SKPhotoMediaProtocol)?.mediaType ?? .image == .image {
                displayImage(complete: true)
                return
            }
            if let _ = photo {
                displayImage(complete: false)
            }
        }
    }
    public var progress: Double = 0{
        didSet{
            indicatorView.progress = progress
        }
    }
    
    fileprivate weak var browser: SKPhotoBrowser?
    
    fileprivate(set) var imageView: SKDetectingImageView!
    fileprivate var tapView: SKDetectingView!
    fileprivate var indicatorView: SKProgressMaskView!
    fileprivate var player: AVPlayer?
    fileprivate var playerLayer: AVPlayerLayer?
    fileprivate var livePhotoView: UIView?
    fileprivate var playerEndObserver: NSObjectProtocol?
    fileprivate var isMediaPlaying = false

    var shouldShowMediaPlayButton: Bool {
        return (player != nil || livePhotoView != nil) && (photo?.progress ?? 0) >= 1
    }

    var shouldShowLivePhotoBadge: Bool {
        return livePhotoView != nil
    }

    var mediaIsPlaying: Bool {
        return isMediaPlaying
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    convenience init(frame: CGRect, browser: SKPhotoBrowser) {
        self.init(frame: frame)
        self.browser = browser
        setup()
    }
    
    deinit {
        browser = nil
    }
    
    func setup() {
        // tap
        tapView = SKDetectingView(frame: bounds)
        tapView.delegate = self
        tapView.backgroundColor = .clear
        tapView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        addSubview(tapView)
        
        // image
        imageView = SKDetectingImageView(frame: frame)
        imageView.delegate = self
        imageView.contentMode = .bottom
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        addSubview(imageView)
        
        // indicator
        indicatorView = SKProgressMaskView(frame: frame)
        addSubview(indicatorView)

        // self
        backgroundColor = .clear
        delegate = self
        showsHorizontalScrollIndicator = SKPhotoBrowserOptions.displayHorizontalScrollIndicator
        showsVerticalScrollIndicator = SKPhotoBrowserOptions.displayVerticalScrollIndicator
        if #available(iOS 11.0, *) {
            contentInsetAdjustmentBehavior = .never
        }
        autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin, .flexibleRightMargin, .flexibleLeftMargin]
    }
    
    // MARK: - override
    
    open override func layoutSubviews() {
        tapView.frame = bounds
        indicatorView.frame = bounds
        
        super.layoutSubviews()
        
        let boundsSize = bounds.size
        var frameToCenter = imageView.frame
        
        // horizon
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = floor((boundsSize.width - frameToCenter.size.width) / 2)
        } else {
            frameToCenter.origin.x = 0
        }
        // vertical
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = floor((boundsSize.height - frameToCenter.size.height) / 2)
        } else {
            frameToCenter.origin.y = 0
        }
        frameToCenter.origin.y += hiddenToolbarVerticalOffset()
        
        // Center
        if !imageView.frame.equalTo(frameToCenter) {
            imageView.frame = frameToCenter
        }
        
        playerLayer?.frame = imageView.bounds
        livePhotoView?.frame = imageView.bounds
    }
    
    open func setMaxMinZoomScalesForCurrentBounds() {
        maximumZoomScale = 1
        minimumZoomScale = 1
        zoomScale = 1
        
        guard let imageView = imageView else {
            return
        }
        
        let boundsSize = bounds.size
        let imageSize = imageView.frame.size
        
        let xScale = boundsSize.width / imageSize.width
        let yScale = boundsSize.height / imageSize.height
        var minScale: CGFloat = min(xScale.isNormal ? xScale : 1.0, yScale.isNormal ? yScale : 1.0)
        var maxScale: CGFloat = 1.0
        
        let scale = max(SKMesurement.screenScale, 2.0)
        let deviceScreenWidth = SKMesurement.screenWidth * scale // width in pixels. scale needs to remove if to use the old algorithm
        let deviceScreenHeight = SKMesurement.screenHeight * scale // height in pixels. scale needs to remove if to use the old algorithm
        
        if SKPhotoBrowserOptions.longPhotoWidthMatchScreen && imageView.frame.height >= imageView.frame.width {
            minScale = 1.0
            maxScale = 2.5
        } else if imageView.frame.width < deviceScreenWidth {
            // I think that we should to get coefficient between device screen width and image width and assign it to maxScale. I made two mode that we will get the same result for different device orientations.
            if UIApplication.shared.statusBarOrientation.isPortrait {
                maxScale = deviceScreenHeight / imageView.frame.width
            } else {
                maxScale = deviceScreenWidth / imageView.frame.width
            }
        } else if imageView.frame.width > deviceScreenWidth {
            maxScale = 1.0
        } else {
            // here if imageView.frame.width == deviceScreenWidth
            maxScale = 2.5
        }
        
        maximumZoomScale = maxScale
        minimumZoomScale = minScale
        zoomScale = minScale
        
        // on high resolution screens we have double the pixel density, so we will be seeing every pixel if we limit the
        // maximum zoom scale to 0.5
        // After changing this value, we still never use more
         maxScale /= scale
         if maxScale < minScale {
             maxScale = minScale * 2
         }

        // reset position
        imageView.frame.origin = CGPoint.zero
        setNeedsLayout()
    }
    
    open func prepareForReuse() {
        pause()
        clearMediaViews()
        updatePlayButton(hidden: true)
        updateLivePhotoBadge(hidden: true)
        photo = nil
        if captionView != nil {
            captionView?.removeFromSuperview()
            captionView = nil
        }
    }
    
    open func displayImage(_ image: UIImage) {
        clearMediaViews()
        // image
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        updatePlayButton(hidden: true)
        updateLivePhotoBadge(hidden: true)
        
        var imageViewFrame: CGRect = .zero
        imageViewFrame.origin = .zero
        // long photo
        if SKPhotoBrowserOptions.longPhotoWidthMatchScreen && image.size.height >= image.size.width {
            let imageHeight = SKMesurement.screenWidth / image.size.width * image.size.height
            imageViewFrame.size = CGSize(width: SKMesurement.screenWidth, height: imageHeight)
        } else {
            imageViewFrame.size = image.size
        }
        imageView.frame = imageViewFrame
        
        contentSize = imageViewFrame.size
        setMaxMinZoomScalesForCurrentBounds()
    }
    
    // MARK: - image
    open func displayImage(complete flag: Bool) {
        clearMediaViews()
        // reset scale
        maximumZoomScale = 1
        minimumZoomScale = 1
        zoomScale = 1
        
        if !flag {
            indicatorView.progress = 1
            photo?.loadUnderlyingImageAndNotify()
        } else {
            indicatorView.progress = photo?.progress ?? 0
        }
        
        if !displayMediaIfPossible() {
            if let image = photo?.underlyingImage {
                displayImage(image)
            } else {
                // change contentSize will reset contentOffset, so only set the contentsize zero when the image is nil
                contentSize = CGSize.zero
            }
        }
        setNeedsLayout()
    }
    
    open func displayImageFailure() {
        photo?.progress = 1
        indicatorView.progress = 1
    }

    open func play() {
        if #available(iOS 9.1, *), let livePhotoView = livePhotoView as? PHLivePhotoView {
            livePhotoView.startPlayback(with: .full)
            isMediaPlaying = true
            updatePlayButton()
            return
        }
        player?.play()
        isMediaPlaying = true
        updatePlayButton()
    }

    open func pause() {
        if #available(iOS 9.1, *), let livePhotoView = livePhotoView as? PHLivePhotoView {
            livePhotoView.stopPlayback()
        }
        player?.pause()
        isMediaPlaying = false
        updatePlayButton()
    }

    func toggleMediaPlayback() {
        togglePlayback()
    }

    @objc func togglePlayback() {
        if isMediaPlaying {
            pause()
        } else {
            play()
        }
        browser?.hideControlsAfterDelay()
    }
    
    // MARK: - handle tap
    open func handleDoubleTap(_ touchPoint: CGPoint) {
        if let browser = browser {
            NSObject.cancelPreviousPerformRequests(withTarget: browser)
        }
        
        if zoomScale > minimumZoomScale {
            // zoom out
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            // zoom in
            // I think that the result should be the same after double touch or pinch
            /* var newZoom: CGFloat = zoomScale * 3.13
             if newZoom >= maximumZoomScale {
             newZoom = maximumZoomScale
             }
             */
            let zoomRect = zoomRectForScrollViewWith(maximumZoomScale, touchPoint: touchPoint)
            zoom(to: zoomRect, animated: true)
        }
        
        // delay control
        browser?.hideControlsAfterDelay()
    }
}

// MARK: - UIScrollViewDelegate

extension SKZoomingScrollView: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        browser?.cancelControlHiding()
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        setNeedsLayout()
        layoutIfNeeded()
    }
}

// MARK: - SKDetectingImageViewDelegate

extension SKZoomingScrollView: SKDetectingViewDelegate {
    func handleSingleTap(_ view: UIView, touch: UITouch) {
        guard let browser = browser else {
            return
        }
        guard SKPhotoBrowserOptions.enableZoomBlackArea == true else {
            return
        }
        
        if browser.areControlsHidden() == false && SKPhotoBrowserOptions.enableSingleTapDismiss == true {
            browser.determineAndClose()
        } else {
            browser.toggleControls()
        }
    }
    
    func handleDoubleTap(_ view: UIView, touch: UITouch) {
        if SKPhotoBrowserOptions.enableZoomBlackArea == true {
            let needPoint = getViewFramePercent(view, touch: touch)
            handleDoubleTap(needPoint)
        }
    }
}

// MARK: - SKDetectingImageViewDelegate

extension SKZoomingScrollView: SKDetectingImageViewDelegate {
    func handleImageViewSingleTap(_ touchPoint: CGPoint) {
        guard let browser = browser else {
            return
        }
        if SKPhotoBrowserOptions.enableSingleTapDismiss {
            browser.determineAndClose()
        } else {
            browser.toggleControls()
        }
    }
    
    func handleImageViewDoubleTap(_ touchPoint: CGPoint) {
        handleDoubleTap(touchPoint)
    }
}

@available(iOS 9.1, *)
extension SKZoomingScrollView: PHLivePhotoViewDelegate {
    public func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        isMediaPlaying = false
        updatePlayButton()
    }
}

private extension SKZoomingScrollView {
    func displayMediaIfPossible() -> Bool {
        guard let mediaPhoto = photo as? SKPhotoMediaProtocol else {
            return false
        }

        switch mediaPhoto.mediaType {
        case .image:
            return false
        case .video:
            guard (photo?.progress ?? 0) >= 1 else {
                return false
            }
            guard let videoURL = mediaPhoto.videoURL else {
                return false
            }
            configureMediaFrame()
            imageView.image = nil
            imageView.contentMode = .scaleAspectFit

            let player = AVPlayer(url: videoURL)
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspect
            layer.frame = imageView.bounds
            imageView.layer.addSublayer(layer)

            self.player = player
            self.playerLayer = layer
            updateLivePhotoBadge(hidden: true)
            playerEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main) { [weak self] _ in
                    self?.player?.seek(to: CMTime.zero)
                    self?.isMediaPlaying = false
                    self?.updatePlayButton()
                }
            isMediaPlaying = false
            updatePlayButton(hidden: false)
            return true
        case .livePhoto:
            guard (photo?.progress ?? 0) >= 1 else {
                return false
            }
            guard #available(iOS 9.1, *), let livePhoto = mediaPhoto.livePhoto else {
                return false
            }
            configureMediaFrame()
            imageView.image = nil

            let liveView = PHLivePhotoView(frame: imageView.bounds)
            liveView.livePhoto = livePhoto
            liveView.contentMode = .scaleAspectFit
            liveView.clipsToBounds = true
            liveView.delegate = self
            imageView.addSubview(liveView)

            livePhotoView = liveView
            isMediaPlaying = false
            updatePlayButton(hidden: false)
            updateLivePhotoBadge(hidden: false)
            return true
        }
    }

    func configureMediaFrame() {
        var size = bounds.size
        if let imageSize = photo?.underlyingImage?.size, imageSize != .zero {
            size = imageSize
        }
        if size == .zero {
            size = CGSize(width: SKMesurement.screenWidth, height: SKMesurement.screenHeight)
        }

        imageView.frame = CGRect(origin: .zero, size: size)
        contentSize = size
        setMaxMinZoomScalesForCurrentBounds()
    }

    func clearMediaViews() {
        if let playerEndObserver = playerEndObserver {
            NotificationCenter.default.removeObserver(playerEndObserver)
            self.playerEndObserver = nil
        }
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player?.pause()
        player = nil
        isMediaPlaying = false
        if #available(iOS 9.1, *), let livePhotoView = livePhotoView as? PHLivePhotoView {
            livePhotoView.stopPlayback()
        }
        livePhotoView?.removeFromSuperview()
        livePhotoView = nil
        updatePlayButton(hidden: true)
        updateLivePhotoBadge(hidden: true)
    }

    func updatePlayButton(hidden: Bool? = nil) {
        browser?.refreshMediaControls(for: self)
    }

    func updateLivePhotoBadge(hidden: Bool) {
        browser?.refreshMediaControls(for: self)
    }

    func getViewFramePercent(_ view: UIView, touch: UITouch) -> CGPoint {
        let oneWidthViewPercent = view.bounds.width / 100
        let viewTouchPoint = touch.location(in: view)
        let viewWidthTouch = viewTouchPoint.x
        let viewPercentTouch = viewWidthTouch / oneWidthViewPercent
        let photoWidth = imageView.bounds.width
        let onePhotoPercent = photoWidth / 100
        let needPoint = viewPercentTouch * onePhotoPercent
        
        var Y: CGFloat!
        
        if viewTouchPoint.y < view.bounds.height / 2 {
            Y = 0
        } else {
            Y = imageView.bounds.height
        }
        let allPoint = CGPoint(x: needPoint, y: Y)
        return allPoint
    }
    
    func zoomRectForScrollViewWith(_ scale: CGFloat, touchPoint: CGPoint) -> CGRect {
        let w = frame.size.width / scale
        let h = frame.size.height / scale
        let x = touchPoint.x - (h / max(SKMesurement.screenScale, 2.0))
        let y = touchPoint.y - (w / max(SKMesurement.screenScale, 2.0))
        
        return CGRect(x: x, y: y, width: w, height: h)
    }

    func hiddenToolbarVerticalOffset() -> CGFloat {
        guard browser?.toolbarType == SKPhotoBrowserToolBarType.none else {
            return 0
        }

        if let toolbar = browser?.toolbar, toolbar.frame.height > 0 {
            return toolbar.frame.height / 2
        }
        if let toolbarHeight = browser?.frameForToolbarAtOrientation().height, toolbarHeight > 0 {
            return toolbarHeight / 2
        }
        return 22
    }
}
