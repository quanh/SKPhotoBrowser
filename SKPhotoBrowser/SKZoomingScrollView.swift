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
    fileprivate var playButton: UIButton!
    fileprivate var livePhotoBadgeView: UIImageView!
    fileprivate var isMediaPlaying = false
    
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

        // play
        playButton = UIButton(type: .custom)
        playButton.tintColor = .white
        playButton.imageView?.contentMode = .scaleAspectFill
        if #available(iOS 17.0, *) {
            playButton.imageView?.preferredImageDynamicRange = .high
        } else {
            // Fallback on earlier versions
        }
        if #available(iOS 13.0, *) {
            playButton.setImage(UIImage(systemName: "play.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 48)), for: .normal)
        }
        playButton.isHidden = true
        playButton.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)
        addSubview(playButton)

        livePhotoBadgeView = UIImageView()
        livePhotoBadgeView.tintColor = .white
        livePhotoBadgeView.contentMode = .center
        if #available(iOS 13.0, *) {
            livePhotoBadgeView.image = UIImage(systemName: "livephoto", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24))
        }
        livePhotoBadgeView.isHidden = true
        addSubview(livePhotoBadgeView)
        
        // self
        backgroundColor = .clear
        delegate = self
        showsHorizontalScrollIndicator = SKPhotoBrowserOptions.displayHorizontalScrollIndicator
        showsVerticalScrollIndicator = SKPhotoBrowserOptions.displayVerticalScrollIndicator
        autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin, .flexibleRightMargin, .flexibleLeftMargin]
    }
    
    // MARK: - override
    
    open override func layoutSubviews() {
        tapView.frame = bounds
        indicatorView.frame = bounds
        playButton.frame = CGRect(
            x: safeAreaAdjustedBounds.midX - 28,
            y: safeAreaAdjustedBounds.midY - 28,
            width: 56,
            height: 56)
        livePhotoBadgeView.frame = CGRect(
            x: imageView.frame.minX + 16,
            y: imageView.frame.minY + 48,
            width: 24,
            height: 24)
        
        super.layoutSubviews()
        
        let visibleBounds = safeAreaAdjustedBounds
        let boundsSize = visibleBounds.size
        var frameToCenter = imageView.frame
        
        // horizon
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = visibleBounds.minX + floor((boundsSize.width - frameToCenter.size.width) / 2)
        } else {
            frameToCenter.origin.x = visibleBounds.minX
        }
        // vertical
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = visibleBounds.minY + floor((boundsSize.height - frameToCenter.size.height) / 2)
        } else {
            frameToCenter.origin.y = visibleBounds.minY
        }
        
        // Center
        if !imageView.frame.equalTo(frameToCenter) {
            imageView.frame = frameToCenter
        }
        playerLayer?.frame = imageView.bounds
        livePhotoView?.frame = imageView.bounds
        livePhotoBadgeView.frame = CGRect(
            x: imageView.frame.minX + 16,
            y: imageView.frame.minY + 48,
            width: 24,
            height: 24)
    }
    
    open func setMaxMinZoomScalesForCurrentBounds() {
        maximumZoomScale = 1
        minimumZoomScale = 1
        zoomScale = 1
        
        guard let imageView = imageView else {
            return
        }
        
        let boundsSize = safeAreaAdjustedBounds.size
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
            let width = safeAreaAdjustedBounds.width
            let imageHeight = width / image.size.width * image.size.height
            imageViewFrame.size = CGSize(width: width, height: imageHeight)
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
            indicatorView.progress = 0
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
    var safeAreaAdjustedBounds: CGRect {
        guard #available(iOS 11.0, *) else {
            return bounds
        }
        let rect = bounds.inset(by: safeAreaInsets)
        return CGRect(origin: rect.origin, size: CGSize(width: rect.width, height: rect.height - 24))
    }

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
            layer.frame = imageView.bounds.insetBy(dx: 0, dy: 48)
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

            let liveView = PHLivePhotoView(frame: imageView.bounds.insetBy(dx: 0, dy: 48))
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
        var size = safeAreaAdjustedBounds.size
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
        if let hidden = hidden {
            playButton.isHidden = hidden || (photo?.progress ?? 0) < 1
        } else {
            playButton.isHidden = (player == nil && livePhotoView == nil) || (photo?.progress ?? 0) < 1
        }
        if #available(iOS 13.0, *) {
            if isMediaPlaying{
                playButton.setImage(nil, for: .normal)
            }else{
                playButton.setImage(UIImage(systemName: "play.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 48)), for: .normal)
            }
        } else {
            playButton.setTitle(isMediaPlaying ? "Pause" : "Play", for: .normal)
        }
    }

    func updateLivePhotoBadge(hidden: Bool) {
        livePhotoBadgeView.isHidden = hidden
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
}
