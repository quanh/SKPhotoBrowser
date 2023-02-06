//
//  SKProgressMaskView.swift
//  SKPhotoBrowser
//
//  Created by 权海 on 2023/2/6.
//  Copyright © 2023 suzuki_keishi. All rights reserved.
//

import Foundation
import UIKit


public class SKProgressMaskView: UIView{
    
    public var progress: Double = 0{
        didSet{
            preProgress = oldValue
//            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.25) {
                    self.layer.opacity = self.progress == 1 ? 0 : 1
                }
                self.playAnimation()
//            }
        }
    }
    private var preProgress: Double = 0
    
    public var progressWidthHeight: CGFloat = 58
    public var progressLineWidth: CGFloat = 6
    public var progressBgColor: UIColor = UIColor(white: 1, alpha: 0.35)
    public var progressColor: UIColor = .white
    
    lazy private var bgLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.frame = CGRect(x: 0, y: 0, width: progressWidthHeight, height: progressWidthHeight)
        layer.lineWidth = progressLineWidth
        layer.strokeColor = progressBgColor.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.path = layerPath().cgPath
        layer.strokeStart = 0
        layer.strokeEnd = 1
        return layer
    }()
    lazy private var forenLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.frame = CGRect(x: 0, y: 0, width: progressWidthHeight, height: progressWidthHeight)
        layer.lineWidth = progressLineWidth
        layer.strokeColor = progressColor.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.path = layerPath().cgPath
        layer.strokeStart = 0
        layer.strokeEnd = 0
        return layer
    }()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.65)
        isUserInteractionEnabled = false
        layer.opacity = 0
        layer.addSublayer(bgLayer)
        layer.addSublayer(forenLayer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        let x: CGFloat = (bounds.width - progressWidthHeight)/2
        let y: CGFloat = (bounds.height - progressWidthHeight)/2
        bgLayer.frame = CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: progressWidthHeight, height: progressWidthHeight))
        forenLayer.frame = CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: progressWidthHeight, height: progressWidthHeight))
    }

    private func layerPath() -> UIBezierPath{
        let startAngle: Double = -90*Double.pi/180
        let endAngle: Double = 270*Double.pi/180
        
        let path = UIBezierPath(arcCenter: CGPoint(x: progressWidthHeight/2, y: progressWidthHeight/2), radius: progressWidthHeight/2, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        return path
    }
    
    private func playAnimation(){
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = 0.2
        animation.timingFunction = .init(name: .easeInEaseOut)
        animation.fromValue = preProgress
        animation.toValue = progress
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        forenLayer.add(animation, forKey: nil)
    }
}
