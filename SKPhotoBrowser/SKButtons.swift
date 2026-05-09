//
//  SKButtons.swift
//  SKPhotoBrowser
//
//  Created by 鈴木 啓司 on 2016/08/09.
//  Copyright © 2016年 suzuki_keishi. All rights reserved.
//

import UIKit

class SKButton: UIControl {
    internal var showFrame: CGRect!
    internal var hideFrame: CGRect!
    internal let imageView = UIImageView()
    
    fileprivate let size: CGSize = CGSize(width: 44, height: 44)
    fileprivate var marginX: CGFloat = 0
    fileprivate var marginY: CGFloat = 0
    fileprivate var extraMarginY: CGFloat = 20 //NOTE: dynamic to static
    
    private var normalImage: UIImage?
    
    override var isSelected: Bool{
        didSet{
            updateStateImage()
        }
    }
    override var isHighlighted: Bool{
        didSet{
            updateStateImage()
        }
    }
    override var isEnabled: Bool{
        didSet{
            updateStateImage()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit

        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin]

        addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateStateImage(){
        imageView.image = normalImage
    }

    func setImage(_ image: UIImage?, for state: UIControl.State) {
        guard state == .normal else {
            return
        }
        normalImage = image
        updateStateImage()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateImageViewFrame()
    }
    private func updateImageViewFrame(){
        imageView.bounds = CGRect(origin: .zero, size: SKButtonOptions.buttonImageSize)
        imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
  
    func setFrameSize(_ size: CGSize? = nil) {
        guard let size = size else { return }
        
        let newRect = CGRect(x: marginX, y: marginY, width: size.width, height: size.height)
        frame = newRect
        showFrame = newRect
        hideFrame = CGRect(x: marginX, y: -marginY, width: size.width, height: size.height)
        updateImageViewFrame()
    }
}


class SKCloseButton: SKButton {
    override var marginX: CGFloat {
        get {
            return SKPhotoBrowserOptions.swapActionButtons
                ? SKMesurement.screenWidth - SKButtonOptions.closeButtonPadding.x - self.size.width
                : SKButtonOptions.closeButtonPadding.x
        }
        set { super.marginX = newValue }
    }
    override var marginY: CGFloat {
        get { return SKButtonOptions.closeButtonPadding.y + extraMarginY }
        set { super.marginY = newValue }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        showFrame = CGRect(x: marginX, y: marginY, width: size.width, height: size.height)
        hideFrame = CGRect(x: marginX, y: -marginY, width: size.width, height: size.height)
        setImage(UIImage.bundledImage(named: "btn_common_close_wh"), for: .normal)
    }
}

class SKDeleteButton: SKButton {
    override var marginX: CGFloat {
        get {
            return SKPhotoBrowserOptions.swapActionButtons
                ? SKButtonOptions.deleteButtonPadding.x
                : SKMesurement.screenWidth - SKButtonOptions.deleteButtonPadding.x - self.size.width
        }
        set { super.marginX = newValue }
    }
    override var marginY: CGFloat {
        get { return SKButtonOptions.deleteButtonPadding.y + extraMarginY }
        set { super.marginY = newValue }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        showFrame = CGRect(x: marginX, y: marginY, width: size.width, height: size.height)
        hideFrame = CGRect(x: marginX, y: -marginY, width: size.width, height: size.height)
        setImage(UIImage.bundledImage(named: "btn_common_delete_wh"), for: .normal)
    }
}

class SKDownloadButton: SKButton {
    override var marginX: CGFloat {
        get {
            return SKPhotoBrowserOptions.swapActionButtons
                ? SKButtonOptions.downloadButtonPadding.x
                : SKMesurement.screenWidth - SKButtonOptions.downloadButtonPadding.x - self.size.width
        }
        set { super.marginX = newValue }
    }
    override var marginY: CGFloat {
        get { return SKButtonOptions.downloadButtonPadding.y + extraMarginY }
        set { super.marginY = newValue }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        showFrame = CGRect(x: marginX, y: marginY, width: size.width, height: size.height)
        hideFrame = CGRect(x: marginX, y: -marginY, width: size.width, height: size.height)
        setImage(UIImage.bundledImage(named: "btn_common_download_wh"), for: .normal)
    }
}
