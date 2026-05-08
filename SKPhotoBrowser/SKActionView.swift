//
//  SKOptionalActionView.swift
//  SKPhotoBrowser
//
//  Created by keishi_suzuki on 2017/12/19.
//  Copyright © 2017年 suzuki_keishi. All rights reserved.
//

import UIKit

class SKActionView: UIView {
    internal weak var browser: SKPhotoBrowser?
    internal var closeButton: SKCloseButton!
    internal var deleteButton: SKDeleteButton!
    internal var playButton: UIButton!
    internal var livePhotoBadgeView: UIImageView!
    
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
        configureMediaControls()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let view = super.hitTest(point, with: event) {
            if closeButton.frame.contains(point)
                || deleteButton.frame.contains(point)
                || (!playButton.isHidden && playButton.frame.contains(point)) {
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

    func updateMediaControls(for page: SKZoomingScrollView?) {
        guard let page = page else {
            playButton.isHidden = true
            livePhotoBadgeView.isHidden = true
            return
        }

        playButton.isHidden = !page.shouldShowMediaPlayButton
        livePhotoBadgeView.isHidden = !page.shouldShowLivePhotoBadge

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

    func updateCloseButton(image: UIImage, size: CGSize? = nil) {
        configureCloseButton(image: image, size: size)
    }
    
    func updateDeleteButton(image: UIImage, size: CGSize? = nil) {
        configureDeleteButton(image: image, size: size)
    }
    
    func animate(hidden: Bool) {
        let closeFrame: CGRect = hidden ? closeButton.hideFrame : closeButton.showFrame
        let deleteFrame: CGRect = hidden ? deleteButton.hideFrame : deleteButton.showFrame
        UIView.animate(withDuration: 0.35,
                       animations: { () -> Void in
                        let alpha: CGFloat = hidden ? 0.0 : 1.0

                        if SKPhotoBrowserOptions.displayCloseButton {
                            self.closeButton.alpha = alpha
                            self.closeButton.frame = closeFrame
                        }
                        if SKPhotoBrowserOptions.displayDeleteButton {
                            self.deleteButton.alpha = alpha
                            self.deleteButton.frame = deleteFrame
                        }
        }, completion: nil)
    }
    
    @objc func closeButtonPressed(_ sender: UIButton) {
        browser?.determineAndClose()
    }
    
    @objc func deleteButtonPressed(_ sender: UIButton) {
        guard let browser = self.browser else { return }
        
        browser.delegate?.removePhoto?(browser, index: browser.currentPageIndex) { [weak self] in
            self?.browser?.deleteImage()
        }
    }

    @objc func playButtonPressed(_ sender: UIButton) {
        browser?.pageDisplayedAtIndex(browser?.currentPageIndex ?? 0)?.toggleMediaPlayback()
    }
}

extension SKActionView {
    func configureCloseButton(image: UIImage? = nil, size: CGSize? = nil) {
        if closeButton == nil {
            closeButton = SKCloseButton(frame: .zero)
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
            deleteButton = SKDeleteButton(frame: .zero)
            deleteButton.addTarget(self, action: #selector(deleteButtonPressed(_:)), for: .touchUpInside)
            deleteButton.isHidden = !SKPhotoBrowserOptions.displayDeleteButton
            addSubview(deleteButton)
        }
        
        if let size = size {
            deleteButton.setFrameSize(size)
        }
        
        if let image = image {
            deleteButton.setImage(image, for: .normal)
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
    }
}
