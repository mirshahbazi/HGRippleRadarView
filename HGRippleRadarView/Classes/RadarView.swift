//
//  RadarView.swift
//  HGNearbyUsers_Example
//
//  Created by Hamza Ghazouani on 25/01/2018.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit


/// A radar view with ripple animation
@IBDesignable
final public class RadarView: RippleView {
    
    // MARK: public properties
    
    /// the maximum number of items that can be shown in the radar view, if you use more, some layers will overlaying other layers
    public var circleCapacity: Int {
        if allPossiblePositions.isEmpty {
            findPossiblePositions()
        }
        return allPossiblePositions.count
    }
    
    /// The padding between items, the default value is 10
    @IBInspectable public var paddingBetweenItems: CGFloat = 10 {
        didSet {
            redrawItems()
        }
    }
    
    /// The delegate of the radar view
    public weak var delegate: RadarViewDelegate?
    /// The data source of the radar view
    public weak var dataSource: RadarViewDataSource?

    // MARK: private properties
    
    /// All possible positions to draw item in the radar view, you can have more positions if you have more circles
    private var allPossiblePositions = [CGPoint]()

    /// All available position to draw items
    private var availablePositions = [CGPoint]()
    
    /// items drawn in the radar view
    private var itemsLayer = [ItemLayer]()
    
    /// layer to remove after hidden animation
    private var layerToRemove: CALayer?
    
    /// the preferable radius of an item
    private var itemRadius: CGFloat {
        return paddingBetweenCircles / 3
    }
    
    // MARK: View Life Cycle
    
    override func setup() {
        if circlesPadding > 40 {
            paddingBetweenCircles = 40
        }
        minimumCircleRadius = 60
        backgroundColor = .ripplePinkDark
        
        super.setup()
    }
    
    /// Lays out subviews.
    override public func layoutSubviews() {
        super.layoutSubviews()
        
       redrawItems()
    }
    
    override func redrawCircles() {
        super.redrawCircles()
        
        redrawItems()
    }
    
    private func redrawItems() {
        // remove all items and redraw them in the right positions
        let items = itemsLayer
        allPossiblePositions.removeAll()
        availablePositions.removeAll()
        itemsLayer.removeAll()
        
        findPossiblePositions()
        availablePositions = allPossiblePositions
        
        items.forEach {
            $0.layer.removeFromSuperlayer()
            var index = $0.index
            add(item: $0.item, at: &index)
        }
    }
    
    // MARK: Utilities methods
    
    /// browse circles and find possible position to draw layer
    private func findPossiblePositions() {
        for (index, layer) in circlesLayer.enumerated() {
            let origin = layer.position
            let radius = radiusOfCircle(at: index)
            let circle = Circle(origin: origin, radius:radius)
            
            // we calculate the capacity using: (2π * r1 / 2 * r2) ; r2 = (itemRadius + padding/2)
            let capicity = (radius * CGFloat.pi) / (itemRadius + paddingBetweenItems/2)
            
            /*
             Random Angle is used  to don't have the gap in the same place, we should find a better solution
             for example, dispatch the gap as padding between items
             let randomAngle = CGFloat(arc4random_uniform(UInt32(Float.pi * 2)))
             */
            for index in 0 ..< Int(capicity) {
                let angle = ((CGFloat(index) * 2 * CGFloat.pi) / CGFloat(capicity))/* + randomAngle */
                let itemOrigin = Geometry.point(in: angle, of: circle)
                allPossiblePositions.append(itemOrigin)
            }
        }
    }

    /// Add item layer to radar view
    ///
    /// - Parameters:
    ///   - item: item to add to the radar view
    ///   - index: the index of the item layer (position)
    ///   - animation: the animation used to show the item layer
    private func add(item: Item, at index: inout Int, using animation: CAAnimation = Animation.transform()) {
        
        if allPossiblePositions.isEmpty {
            findPossiblePositions()
        }
        if availablePositions.count == 0 {
            print("HGRipplerRadarView Warning: you use more than the capacity of the radar view, some layers will overlaying other layers")
            availablePositions = allPossiblePositions
        }
        
        // try to draw the item in a precise position, if it's not possible, a random index is used
        if index >= availablePositions.count {
           index = Int(arc4random_uniform(UInt32(availablePositions.count)))
        }
        let origin = availablePositions[index]
        availablePositions.remove(at: index)
        
        let preferredSize = CGSize(width: itemRadius*2, height: itemRadius*2)
        let customLayer = dataSource?.radarView(radarView: self, viewFor: item, preferredSize: preferredSize).layer
        let layer = customLayer ?? Drawer.diskLayer(radius: itemRadius, origin: origin, color: UIColor.turquoise.cgColor)
        layer.position = origin
        
        layer.transform = CATransform3DMakeScale(0.0, 0.0, 1.0)
        layer.add(animation, forKey: nil)
        
        self.layer.addSublayer(layer)
        let itemLayer = ItemLayer(layer: layer, item: item, index: index)
        itemsLayer.append(itemLayer)
    }

    /// Remove layer from radar view
    ///
    /// - Parameter layer: the layer to remove
    private func removeWithAnimation(layer: CALayer) {
       let hideAnimation = Animation.hide()
        hideAnimation.delegate = self
        
        layer.add(hideAnimation, forKey: nil)
    }
    
    
    // MARK: manage user interaction
    
    /// Tells this object that one or more new touches occurred in a view or window.
    ///
    /// - Parameters:
    ///   - touches: A set of UITouch instances that represent the touches for the starting phase of the event
    ///   - event: The event to which the touches belong.
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        guard let point = touch?.location(in: self) else { return }
        guard let index = itemsLayer.index(where: {
            let itemLayer = $0.layer
            let frame = CGRect(x: itemLayer.position.x - itemLayer.bounds.midX, y: itemLayer.position.y - itemLayer.bounds.midY, width: itemLayer.bounds.width, height: itemLayer.bounds.height)
            return frame.contains(point)
        }) else { return }
        
        delegate?.radarView(radarView: self, didSelect: itemsLayer[index].item)
    }
}

extension RadarView: CAAnimationDelegate {
    
    /// Tells the delegate the animation has ended.
    ///
    /// - Parameters:
    ///   - anim: The CAAnimation object that has ended.
    ///   - flag: A flag indicating whether the animation has completed by reaching the end of its duration.
    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        layerToRemove?.removeFromSuperlayer()
        layerToRemove = nil
    }
}

// MARK: public methods
extension RadarView {
    /// Add a list of items to the radar view
    ///
    /// - Parameters:
    ///   - items: the items to add to the radar view
    ///   - animation: the animation used to show  items layers
   public func add(items: [Item], using animation: CAAnimation = Animation.transform()) {
        for index in 0 ..< items.count {
            animation.beginTime = CACurrentMediaTime() + CFTimeInterval(animation.duration/2 * Double(index))
            self.add(item: items[index], using: animation)
        }
    }
    
    /// Add item randomly in the radar view
    ///
    /// - Parameters:
    ///   - item: the item to add to the radar view
    ///   - animation: the animation used to show  items layers
   public func add(item: Item, using animation: CAAnimation = Animation.transform()) {
        if allPossiblePositions.isEmpty {
            findPossiblePositions()
        }
        
        let count = availablePositions.count == 0 ? allPossiblePositions.count : availablePositions.count
        var randomIndex = Int(arc4random_uniform(UInt32(count)))
        add(item: item, at: &randomIndex, using: animation)
    }
    
    /// Remove item layer from the radar view
    ///
    /// - Parameter item: the item to remove from Radar View
    public func remove(item: Item) {
        guard let index = itemsLayer.index(where: { $0.item.uniqueKey == item.uniqueKey }) else {
            print("\(String(describing: item.uniqueKey)) not found")
            return
        }
        let item = itemsLayer[index]
        removeWithAnimation(layer: item.layer)
        layerToRemove = item.layer
        itemsLayer.remove(at: index)
    }
}