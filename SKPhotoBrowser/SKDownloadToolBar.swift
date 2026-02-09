//
//  SKDownloadToolBar.swift
//  SKPhotoBrowser
//
//  Created by 权海 on 2026/2/9.
//  Copyright © 2026 suzuki_keishi. All rights reserved.
//


class SKDownloadToolBar: SKToolbar {
    fileprivate weak var browser: SKPhotoBrowser?
    override func setupApperance() {
        backgroundColor = .clear
        clipsToBounds = true
        isTranslucent = true
        setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
    
        if #available(iOS 13.0, *) {
            let appearance = UIToolbarAppearance()
            appearance.configureWithTransparentBackground()
            standardAppearance = appearance
            compactAppearance = appearance
            if #available(iOS 15.0, *) {
                scrollEdgeAppearance = appearance
            }
        } else {
            isTranslucent = true
            setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
            setShadowImage(UIImage(), forToolbarPosition: .any)
        }
    }
    override func setupToolbar() {
        toolActionButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: browser, action: #selector(SKPhotoBrowser.downloadButtonOnClick))
        toolActionButton.tintColor = UIColor.white
        
        var items = [UIBarButtonItem]()
        items.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil))
        if SKPhotoBrowserOptions.displayAction {
            items.append(toolActionButton)
        }
        setItems(items, animated: false)
    }
    
    override func setupActionButton() {
    }
}
