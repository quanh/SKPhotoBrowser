//
//  SKButtons.swift
//  SKPhotoBrowser
//
//  Created by 鈴木 啓司 on 2016/08/09.
//  Copyright © 2016年 suzuki_keishi. All rights reserved.
//

import UIKit

class SKButton: UIControl {
    internal let imageView = UIImageView()
    
    fileprivate let size: CGSize = CGSize(width: 44, height: 44)
    fileprivate var marginX: CGFloat = SKButtonOptions.leftPadding
    fileprivate var marginY: CGFloat = 0
    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?

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
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false

        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin]

        addSubview(imageView)
        imageWidthConstraint = imageView.widthAnchor.constraint(equalToConstant: SKButtonOptions.buttonImageSize.width)
        imageHeightConstraint = imageView.heightAnchor.constraint(equalToConstant: SKButtonOptions.buttonImageSize.height)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageWidthConstraint!,
            imageHeightConstraint!,
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 44/2 - SKButtonOptions.buttonImageSize.width/2),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 44/2 - SKButtonOptions.buttonImageSize.height/2)
        ])
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

    func setFrameSize(_ size: CGSize? = nil) {
        guard let size = size else { return }
        
        let newRect = CGRect(x: marginX, y: marginY, width: size.width, height: size.height)
        frame = newRect
    }
}


class SKCloseButton: SKButton {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setImage(UIImage.bundledImage(named: "btn_common_close_wh"), for: .normal)
    }
}

class SKDeleteButton: SKButton {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setImage(UIImage.bundledImage(named: "btn_common_delete_wh"), for: .normal)
    }
}

class SKDownloadButton: SKButton {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setImage(UIImage.bundledImage(named: "btn_common_download_wh"), for: .normal)
    }
}
