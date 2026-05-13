//
//  SKOptionalActionView.swift
//  SKPhotoBrowser
//
//  Created by keishi_suzuki on 2017/12/19.
//  Copyright © 2017年 suzuki_keishi. All rights reserved.
//

import UIKit

class SKVideoControlView: UIView {
    private weak var page: SKZoomingScrollView?
    private let playButton = UIButton(type: .custom)
    private let sliderHitView = UIView()
    private let trackView = UIView()
    private let progressView = UIView()
    private let thumbView = UIView()
    private var progress: CGFloat = 0
    private var isDragging = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func update(isPlaying: Bool, progress: CGFloat, page: SKZoomingScrollView?) {
        self.page = page
        if !isDragging {
            self.progress = min(max(progress, 0), 1)
            setNeedsLayout()
        }
        updatePlayIcon(isPlaying: isPlaying)
    }

    func reset() {
        page = nil
        isDragging = false
        progress = 0
        setNeedsLayout()
        layoutIfNeeded()
        updatePlayIcon(isPlaying: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = bounds.height / 2
        playButton.frame = CGRect(x: 12, y: 0, width: 32, height: bounds.height)

        let sliderX: CGFloat = 48
        let sliderRight: CGFloat = 20
        sliderHitView.frame = CGRect(
            x: sliderX,
            y: 0,
            width: max(0, bounds.width - sliderX - sliderRight),
            height: bounds.height)

        let trackHeight: CGFloat = 4
        let trackY = floor((sliderHitView.bounds.height - trackHeight) / 2)
        trackView.frame = CGRect(x: 0, y: trackY, width: sliderHitView.bounds.width, height: trackHeight)
        progressView.frame = CGRect(x: 0, y: trackY, width: sliderHitView.bounds.width * progress, height: trackHeight)

        let thumbSize: CGFloat = 12
        thumbView.frame = CGRect(
            x: min(max(sliderHitView.bounds.width * progress - thumbSize / 2, -thumbSize / 2), sliderHitView.bounds.width - thumbSize / 2),
            y: floor((sliderHitView.bounds.height - thumbSize) / 2),
            width: thumbSize,
            height: thumbSize)
        trackView.layer.cornerRadius = trackHeight / 2
        progressView.layer.cornerRadius = trackHeight / 2
        thumbView.layer.cornerRadius = thumbSize / 2
    }

    private func setup() {
        backgroundColor = UIColor(white: 0.1, alpha: 0.92)
        clipsToBounds = true

        playButton.tintColor = .white
        playButton.imageView?.contentMode = .scaleAspectFit
        playButton.addTarget(self, action: #selector(playButtonPressed), for: .touchUpInside)
        addSubview(playButton)

        sliderHitView.backgroundColor = .clear
        addSubview(sliderHitView)

        trackView.backgroundColor = UIColor.white.withAlphaComponent(0.24)
        sliderHitView.addSubview(trackView)

        progressView.backgroundColor = .white
        sliderHitView.addSubview(progressView)

        thumbView.backgroundColor = .white
        sliderHitView.addSubview(thumbView)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(sliderGestureChanged(_:)))
        sliderHitView.addGestureRecognizer(panGesture)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(sliderGestureChanged(_:)))
        sliderHitView.addGestureRecognizer(tapGesture)

        updatePlayIcon(isPlaying: false)
    }

    private func updatePlayIcon(isPlaying: Bool) {
        if #available(iOS 13.0, *) {
            let name = isPlaying ? "pause.fill" : "play.fill"
            let image = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
            playButton.setImage(image, for: .normal)
            playButton.setTitle(nil, for: .normal)
        } else {
            playButton.setTitle(isPlaying ? "Pause" : "Play", for: .normal)
            playButton.setImage(nil, for: .normal)
        }
    }

    @objc private func playButtonPressed() {
        page?.toggleMediaPlayback()
    }

    @objc private func sliderGestureChanged(_ gesture: UIGestureRecognizer) {
        let location = gesture.location(in: sliderHitView)
        let width = max(sliderHitView.bounds.width, 1)
        progress = min(max(location.x / width, 0), 1)
        setNeedsLayout()

        if gesture.state == .began || gesture.state == .changed {
            isDragging = true
        }
        if gesture is UITapGestureRecognizer || gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            isDragging = false
//            page?.seekVideo(to: progress)
        }
        page?.seekVideo(to: progress)
    }
}

class SKActionView: UIView {
    internal weak var browser: SKPhotoBrowser?
    internal var closeButton: SKCloseButton!
    internal var deleteButton: SKDeleteButton!
    internal var downloadButton: SKDownloadButton!
    internal var playButton: UIButton!
    internal var livePhotoBadgeView: UIImageView!
    internal var videoControlView: SKVideoControlView!
    fileprivate var actionType: SKPhotoBrowserActionType = .none
    
    // Action
    fileprivate var cancelTitle = "Cancel"
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init(frame: CGRect, browser: SKPhotoBrowser) {
        self.init(frame: frame)
        self.browser = browser

        configureCloseButton()
        configureDeleteButton()
        configureDownloadButton()
        configureMediaControls()
        updateToolbarType(browser.actionType)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let view = super.hitTest(point, with: event) {
            if (!closeButton.isHidden && closeButton.alpha > 0.01 && closeButton.frame.contains(point))
                || (!deleteButton.isHidden && deleteButton.alpha > 0.01 && deleteButton.frame.contains(point))
                || (!downloadButton.isHidden && downloadButton.alpha > 0.01 && downloadButton.frame.contains(point))
                || (!playButton.isHidden && playButton.alpha > 0.01 && playButton.frame.contains(point))
                || (!videoControlView.isHidden && videoControlView.alpha > 0.01 && videoControlView.frame.contains(point)) {
                return view
            }
            return nil
        }
        return nil
    }

    func updateFrame(frame: CGRect) {
        self.frame = frame
        layoutMediaControls()
        setNeedsDisplay()
    }

    func updateToolbarType(_ actionType: SKPhotoBrowserActionType) {
        self.actionType = actionType
        updateToolButtonsVisibility()
    }

    func updateMediaControls(for page: SKZoomingScrollView?) {
        guard let page = page else {
            playButton.isHidden = true
            livePhotoBadgeView.isHidden = true
            videoControlView.isHidden = true
            videoControlView.reset()
            return
        }

        playButton.isHidden = !page.shouldShowMediaPlayButton
        livePhotoBadgeView.isHidden = !page.shouldShowLivePhotoBadge
        videoControlView.isHidden = !page.shouldShowVideoControls
        if page.shouldShowVideoControls {
            videoControlView.update(
                isPlaying: page.mediaIsPlaying,
                progress: page.videoPlaybackProgress,
                page: page)
        } else {
            videoControlView.reset()
        }

        if #available(iOS 13.0, *) {
            if page.mediaIsPlaying {
                playButton.setImage(nil, for: .normal)
            } else {
                playButton.setImage(UIImage(systemName: "play.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 48)), for: .normal)
            }
        } else {
            playButton.setTitle(page.mediaIsPlaying ? "Pause" : "Play", for: .normal)
        }
        layoutMediaControls()
    }
    
    

    func updateActionButton(type: SKPhotoBrowserActionType, image: UIImage, size: CGSize? = nil) {
        switch type {
        case .none:
            break
        case .close:
            configureCloseButton(image: image, size: size)
        case .delete:
            configureDeleteButton(image: image, size: size)
        case .download:
            configureDownloadButton(image: image, size: size)
        }
    }

    
    func animate(hidden: Bool) {
        let closeFrame: CGRect = hidden ? closeButton.hideFrame : closeButton.showFrame
        let deleteFrame: CGRect = hidden ? deleteButton.hideFrame : deleteButton.showFrame
        let downloadFrame: CGRect = hidden ? downloadButton.hideFrame : downloadButton.showFrame
        UIView.animate(withDuration: 0.35,
                       animations: { () -> Void in
                        let alpha: CGFloat = hidden ? 0.0 : 1.0

                        if SKPhotoBrowserOptions.displayCloseButton {
                            self.closeButton.alpha = alpha
                            self.closeButton.frame = closeFrame
                        }
                        if !self.deleteButton.isHidden {
                            self.deleteButton.alpha = alpha
                            self.deleteButton.frame = deleteFrame
                        }
                        if !self.downloadButton.isHidden {
                            self.downloadButton.alpha = alpha
                            self.downloadButton.frame = downloadFrame
                        }
        }, completion: nil)
    }
    
    @objc func closeButtonPressed(_ sender: UIControl) {
        browser?.determineAndClose()
    }
    
    @objc func deleteButtonPressed(_ sender: UIControl) {
        guard let browser = self.browser else { return }
        
        browser.delegate?.removePhoto?(browser, index: browser.currentPageIndex) { [weak self] in
            self?.browser?.deleteImage()
        }
    }

    @objc func downloadButtonPressed(_ sender: UIControl) {
        browser?.downloadButtonOnClick()
    }

    @objc func playButtonPressed(_ sender: UIButton) {
        browser?.pageDisplayedAtIndex(browser?.currentPageIndex ?? 0)?.toggleMediaPlayback()
    }
}

extension SKActionView {
    func configureCloseButton(image: UIImage? = nil, size: CGSize? = nil) {
        if closeButton == nil {
            closeButton = SKCloseButton(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            closeButton.addTarget(self, action: #selector(closeButtonPressed(_:)), for: .touchUpInside)
            closeButton.isHidden = !SKPhotoBrowserOptions.displayCloseButton
            addSubview(closeButton)
        }

        if let size = size {
            closeButton.setFrameSize(size)
        }
        
        if let image = image {
            closeButton.setImage(image, for: .normal)
        }
    }
    
    func configureDeleteButton(image: UIImage? = nil, size: CGSize? = nil) {
        if deleteButton == nil {
            deleteButton = SKDeleteButton(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            deleteButton.addTarget(self, action: #selector(deleteButtonPressed(_:)), for: .touchUpInside)
            deleteButton.isHidden = true
            addSubview(deleteButton)
        }
        
        if let size = size {
            deleteButton.setFrameSize(size)
        }
        
        if let image = image {
            deleteButton.setImage(image, for: .normal)
        }
    }

    func configureDownloadButton(image: UIImage? = nil, size: CGSize? = nil) {
        if downloadButton == nil {
            downloadButton = SKDownloadButton(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            downloadButton.addTarget(self, action: #selector(downloadButtonPressed(_:)), for: .touchUpInside)
            downloadButton.isHidden = true
            addSubview(downloadButton)
        }

        if let size = size {
            downloadButton.setFrameSize(size)
        }

        if let image = image {
            downloadButton.setImage(image, for: .normal)
        }
    }

    func configureMediaControls() {
        if playButton == nil {
            playButton = UIButton(type: .custom)
            playButton.tintColor = .white
            playButton.imageView?.contentMode = .scaleAspectFill
            if #available(iOS 17.0, *) {
                playButton.imageView?.preferredImageDynamicRange = .high
            }
            if #available(iOS 13.0, *) {
                playButton.setImage(UIImage(systemName: "play.circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 48)), for: .normal)
            }
            playButton.isHidden = true
            playButton.addTarget(self, action: #selector(playButtonPressed(_:)), for: .touchUpInside)
            addSubview(playButton)
        }

        if livePhotoBadgeView == nil {
            livePhotoBadgeView = UIImageView()
            livePhotoBadgeView.tintColor = .white
            livePhotoBadgeView.contentMode = .center
            if #available(iOS 13.0, *) {
                livePhotoBadgeView.image = UIImage(systemName: "livephoto", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24))
            }
            livePhotoBadgeView.isHidden = true
            addSubview(livePhotoBadgeView)
        }

        if videoControlView == nil {
            videoControlView = SKVideoControlView(frame: .zero)
            videoControlView.isHidden = true
            addSubview(videoControlView)
        }

        layoutMediaControls()
    }

    func layoutMediaControls() {
        playButton?.frame = CGRect(
            x: bounds.midX - 28,
            y: bounds.midY - 28,
            width: 56,
            height: 56)
        livePhotoBadgeView?.frame = CGRect(
            x: bounds.width - 16 - 24,
            y: safeAreaInsets.top + 48,
            width: 24,
            height: 24)

        let controlWidth = min(bounds.width - 32, 343)
        let toolbarHeight = browser?.toolbarType == SKPhotoBrowserToolBarType.none ? 0 : (browser?.toolbar.frame.height ?? 0)
        let bottomInset = safeAreaInsets.bottom + toolbarHeight + 16
        videoControlView?.frame = CGRect(
            x: floor((bounds.width - controlWidth) / 2),
            y: bounds.height - bottomInset - 40,
            width: controlWidth,
            height: 40)
    }

    func updateToolButtonsVisibility() {
        switch actionType {
        case .none:
            closeButton.isHidden = true
            deleteButton.isHidden = true
            downloadButton.isHidden = true
        case .close:
            closeButton.isHidden = false
            deleteButton.isHidden = true
            downloadButton.isHidden = true
        case .delete:
            closeButton.isHidden = false
            deleteButton.isHidden = false
            downloadButton.isHidden = true
        case .download:
            closeButton.isHidden = false
            deleteButton.isHidden = true
            downloadButton.isHidden = false
        }
    }
}
