//
//  UIApplication+UIWindow.swift
//  SKPhotoBrowser
//
//  Created by Josef Dolezal on 25/09/2017.
//  Copyright © 2017 suzuki_keishi. All rights reserved.
//

import UIKit

internal extension UIWindow{
    @available(iOS 13.0, *)
    static func sk_windowScene() -> UIWindowScene?{
        let connectedScenes = UIApplication.shared.connectedScenes
            .filter({
                $0.activationState == .foregroundActive || $0.activationState ==  .foregroundInactive})
            .compactMap({$0 as? UIWindowScene})
        return connectedScenes.first
    }
}

internal extension UIApplication {
    var sk_Window: UIWindow? {
        // Since delegate window is of type UIWindow??, we have to
        // unwrap it twice to be sure the window is not nil
        if let window = UIApplication.shared.connectedScenes
            .map({ $0 as? UIWindowScene })
            .compactMap({ $0 })
            .first?.windows.first {
            return window
        }else if let window = UIApplication.shared.delegate?.window {
            return window
        }else{
            return nil
        }
    }
    
    var sk_safeAreaInset: UIEdgeInsets{
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            insets = sk_Window?.safeAreaInsets ?? insets
        }
        return insets
    }
    var sk_statusBarHeight: CGFloat{
        if #available(iOS 13.0, *) {
            let statusManager = UIWindow.sk_windowScene()?.statusBarManager
            return statusManager?.statusBarFrame.height ?? 20.0
        } else {
            return UIApplication.shared.statusBarFrame.height
        }
    }
}
