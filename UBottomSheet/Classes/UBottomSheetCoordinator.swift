//
//  Controller.swift
//  BottomSheetDemo
//
//  Created by ugur on 19.04.2020.
//  Copyright © 2020 Sobe. All rights reserved.
//

import UIKit

public enum SheetTranslationState{
    case progressing(_ minYPosition: CGFloat, _ percent: CGFloat) //currently updating
    case willFinish(_ minYPosition: CGFloat, _ percent: CGFloat) //animatiion start
    case finished(_ minYPosition: CGFloat, _ percent: CGFloat) //animation end
}

public class UBottomSheetCoordinator {
    public weak var parent: UIViewController!
    private var container: UIView?
    public weak var dataSource: UBottomSheetCoordinatorDataSource!{
        didSet{
            minSheetPosition = dataSource.sheetPositions(availableHeight).min()
            maxSheetPosition = dataSource.sheetPositions(availableHeight).max()
        }
    }
    public weak var delegate: UBottomSheetCoordinatorDelegate?
    private var minSheetPosition: CGFloat?
    private var maxSheetPosition: CGFloat?
    ///View controllers which conform to Draggable protocol
    private var draggables: [DraggableItem] = []
    ///Drop shadow view behind container.
    private var dropShadowView: PassThroughView?
    /// accept difference equal if in tolerance
    private var tolerance: CGFloat = 0.0000001
    ///set true if sheet view controller is embedded in a UINavigationController
    public var usesNavigationController: Bool = false

    public var availableHeight: CGFloat{
        return parent.view.frame.height
    }
    
    private var cornerRadius: CGFloat = 0{
        didSet{
            applyDefaultShadowParams()
            clearShadowBackground()
        }
    }

    /**
     Creates UBottomSheetCoordinator object.
     
     - parameter parent: UIViewController
     - parameter delegate: UBottomSheetCoordinatorDelegate
     */
    public init(parent: UIViewController, delegate: UBottomSheetCoordinatorDelegate? = nil) {
        self.parent = parent
        self.dataSource = parent
        self.delegate = delegate
        
        minSheetPosition = dataSource.sheetPositions(availableHeight).min()
        maxSheetPosition = dataSource.sheetPositions(availableHeight).max()
    }
    
    /**
     Creates a container view, sets contraints, set initial position, add background view if needed.
     
     You must handle add child on your own. This lets you apply your custom presenting animation.

     # Example #

     Call below code in parent view controller swift file.
     
     ```
     let sheetCoordinator = UBottomSheetCoordinator(parent: self)
     sheetCoordinator.createContainer(with: { (container) in
         container.layer.shadowColor = UIColor.black.cgColor
         container.layer.shadowRadius = 20
         container.layer.shadowOpacity = 0.5
         container.layer.shadowOffset = CGSize(width: -1, height: 1)
         container.layer.masksToBounds = false
         self.view.addSubview(container)
         addChild(child)
         child.view.frame = container.bounds.offsetBy(dx: 0, dy: container.bounds.height)
         container.addSubview(child.view)
         child.didMove(toParent: self)
         
         UIView.animate(withDuration: 0.3) {
             child.view.frame = container.bounds
         }
     })
     
     ```
     FIXME: set frame instead of pinToEdges
     
     - parameter config: Called after container created. So you can customize the view, like shadow, corner radius, border, etc.
     */
    public func createContainer(with config: @escaping (UIView) -> Void){
        let view = PassThroughView()
        self.container = view
        config(view)
        container?.pinToEdges(to: parent.view)
        container?.constraint(parent, for: .top)?.constant = dataSource.sheetPositions(availableHeight)[0]
        setPosition(dataSource.initialPosition(availableHeight), animated: false)
    }
    
    /**
     Creates a container view, adds it as a child to the parent, sets contraints, set initial position, add background view if needed.
     
     # Example #

     Call below code in parent view controller swift file.
     
     ```
     let sheetCoordinator = UBottomSheetCoordinator(parent: self)
     sheetCoordinator.addSheet(vc, to: self, didContainerCreate: { container in
         container.layer.shadowColor = UIColor.black.cgColor
         container.layer.shadowRadius = 10
         container.layer.shadowOpacity = 0.5
         container.layer.shadowOffset = .zero
         container.layer.masksToBounds = false
     })
     ```
     - parameter item: view controller which conforms to the Draggable or navigation controller which contains draggable view controllers.
     - parameter parent: parent view controller
     - parameter didContainerCreate: triggered when container view created so you can modify the container if needed.
     */
    public func addSheet(_ item: UIViewController, to parent: UIViewController, didContainerCreate: ((UIView)->Void)? = nil){
         self.usesNavigationController = item is UINavigationController
         let container = PassThroughView()
         self.container = container
         parent.view.addSubview(container)
         let position = dataSource.initialPosition(availableHeight)
         parent.ub_add(item, in: container, topInset: position){[weak self] in
             guard let sSelf = self else { return }
             sSelf.delegate?.bottomSheet(container, didPresent: .finished(position, sSelf.calculatePercent(at: position)))
         }
         didContainerCreate?(container)
         setPosition(dataSource.initialPosition(availableHeight), animated: false)
     }
    
    /**
     Adds a new view child controller to the current container view
     
     - parameter item: view controller which conforms to the Draggable protocol
     */
    public func addSheetChild(_ item: DraggableItem){
        parent.addChild(item)
        container!.addSubview(item.view)
        item.didMove(toParent: parent)
        item.view.frame = container!.bounds.offsetBy(dx: 0, dy: availableHeight)
        UIView.animate(withDuration: 0.3) {
            item.view.frame = self.container!.bounds
        }
    }
    
    public func addDropShadowIfNotExist(_ config: ((UIView)->Void)? = nil){
        guard dropShadowView == nil else {return}
        dropShadowView = PassThroughView()
        parent.view.insertSubview(dropShadowView!, belowSubview: container!)
        dropShadowView?.pinToEdges(to: container!, insets: UIEdgeInsets(top: -getInitialFrame().minY, left: 0, bottom: 0, right: 0))
        
        self.dropShadowView?.layer.masksToBounds = false
        if config == nil{
            applyDefaultShadowParams()
            clearShadowBackground()
        }else{
            config?(dropShadowView!)
        }
    }
    
    private func getInitialFrame() -> CGRect{
        let minY = parent.view.bounds.minY + dataSource.initialPosition(availableHeight)
        return CGRect(x: parent.view.bounds.minX,
                      y: minY,
                      width: parent.view.bounds.width,
                      height: parent.view.bounds.maxY - minY)
    }
    
    private func applyDefaultShadowParams(){
        dropShadowView?.layer.shadowPath = UIBezierPath(roundedRect: getInitialFrame(), cornerRadius: cornerRadius).cgPath
        dropShadowView?.layer.shadowColor = UIColor.black.cgColor
        dropShadowView?.layer.shadowRadius = CGFloat.init(10)
//        dropShadowView?.layer.shadowOpacity = Float.init(0.5)
        dropShadowView?.layer.shadowOffset = CGSize.init(width: 0.0, height: 4.0)
        let animation = CABasicAnimation(keyPath: "shadowOpacity")
        animation.fromValue = 0.0
        animation.toValue = 0.5
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        animation.duration = 0.3
        dropShadowView?.layer.add(animation, forKey: "fadeout")
    }
    
    private func clearShadowBackground(){
        let p = CGMutablePath()
        p.addRect(parent.view.bounds.insetBy(dx: 0, dy: -availableHeight))
        p.addPath(UIBezierPath(roundedRect: getInitialFrame(), cornerRadius: cornerRadius).cgPath)
        let mask = CAShapeLayer()
        mask.path = p
        mask.fillRule = .evenOdd
        dropShadowView?.layer.mask = mask
    }
    
    /**
     Adjust drop shadow corner radius if exists.
     
     - parameter radius: corner radius
     */
    public func setCornerRadius(_ radius: CGFloat){
        self.cornerRadius = radius
    }
    
    /**
      Set sheet top constraint value to the given new y position.
      
      - parameter minYPosition: new y position.
      - parameter animated: pass true to animate sheet position change; false otherwise.
      */
     public func setPosition(_ minYPosition: CGFloat, animated: Bool){
         self.endTranslate(to: minYPosition, animated: animated)
     }
     
     /**
      Set sheet top constraint value to the nearest sheet positions to given y position.

      - parameter minYPosition: new y position.
      - parameter animated: pass true to animate sheet position change; false otherwise.
      */
     public func setToNearest(_ pos: CGFloat, animated: Bool){
         let y = dataSource.sheetPositions(availableHeight).nearest(to: pos)
         setPosition(y, animated: animated)
     }
    
    /**
     Remove child view controller from the container.
     
     - parameter item: view controller which conforms to the Draggable protocol
     */
    public func removeSheetChild<T: DraggableItem>(item: T){
        stopTracking(item: item)
        let _item = usesNavigationController ? item.navigationController! : item
        UIView.animate(withDuration: 0.3, animations: {
            _item.view.frame = _item.view.frame.offsetBy(dx: 0, dy: _item.view.frame.height)
        }) { (finished) in
            _item.ub_remove()
        }
    }
    
    /**
     Remove sheet from the parent.
     
     - parameter block: use this closure to apply custom sheet dismissal animation
     */
    public func removeSheet(_ block: ((_ container: UIView?)->Void)? = nil){
        self.draggables.removeAll()
        
        if block != nil{
            block?(container)
        }else{
            UIView.animate(withDuration: 0.3, animations: {[weak self] in
                guard let sSelf = self else {return}
                sSelf.container!.frame = sSelf.container!.frame.offsetBy(dx: 0, dy:  sSelf.parent.view.frame.height)
            }) {[weak self]  (finished) in
                self?.container?.removeFromSuperview()
            }
        }
    }
    
    
    /**
     Pan gesture recognizer already set up
     
     - parameter item: view controller which conforms to the Draggable protocol
     */
    private func isTracking<T: DraggableItem>(item: T) -> Bool{
        return draggables.contains { (vc) -> Bool in
            vc == item
        }
    }
     
    /**
     Add pan gesture recognizer to the view controller.
     
     - parameter item: view controller which conforms to the Draggable protocol
     */
    public func startTracking<T: DraggableItem>(item: T){
        guard !isTracking(item: item) else {return}
        item.draggableView()?.panGestureRecognizer.addTarget(self, action: #selector(handleScrollPan(_:)))
        let pan = UIPanGestureRecognizer(target: self, action:  #selector(handleViewPan(_:)))
        item.view.addGestureRecognizer(pan)
        let navBarPan = UIPanGestureRecognizer(target: self, action:  #selector(handleViewPan(_:)))
        item.navigationController?.navigationBar.addGestureRecognizer(navBarPan)
        item.draggableView()?.gestureRecognizers?.forEach({ (recognizer) in
            pan.require(toFail: recognizer)
            navBarPan.require(toFail: recognizer)
        })
        draggables.append(item)
    }
    
    func stopTracking<T: DraggableItem>(item: T){
        draggables.removeAll { (vc) -> Bool in
            vc == item
        }
    }
    
    /**
     Container view pan gesture event
     - parameter recognizer: view pan gesture  object.
    */
    @objc private func handleViewPan(_ recognizer: UIPanGestureRecognizer){
        handlePan(recognizer)
    }

    /**
     Scrollable view pan gesture event
     - parameter recognizer: scroll view pan gesture object.
    */
    @objc private func handleScrollPan(_ recognizer: UIPanGestureRecognizer) {
        guard let scrollView = recognizer.view as? UIScrollView else {return}
        handlePan(recognizer, scrollView: scrollView)
    }
    
    /// Holds last scroll view content offset to stop scrolling while driving the view
    private var lastContentOffset: CGPoint = .zero
    /// As recognizer.setTranslation(.zero, ...) breaks scrollView functionality when driving with scroll view last y translation is used to find the change in y position (dy).
    private var lastY: CGFloat = 0
    
    /**
     Common handler for view and scroll view pan gesture event. drives the sheet according to the container view or scroll view gesture events.
     
     - parameter recognizer: Pan gesture recognizer object.
     - parameter scrollView: set if scrollView gesture event
    */
    private func handlePan(_ recognizer: UIPanGestureRecognizer, scrollView: UIScrollView? = nil){
        let dy = recognizer.translation(in: recognizer.view).y
        let vel = recognizer.velocity(in: recognizer.view)

        switch recognizer.state {
        case .began:
            if let scroll = scrollView{
                lastContentOffset = scroll.contentOffset
                lastY = 0
            }
            totalTranslationMinY = minSheetPosition!
            totalTranslationMaxY = maxSheetPosition!
        case .changed:
            if let scroll = scrollView{
                switch dragDirection(vel) {
                case .up where (container!.frame.minY - minSheetPosition! > tolerance):
                    translate(dy: dy - lastY)
                    scroll.contentOffset.y = lastContentOffset.y
                case .down where scroll.contentOffset.y <= 0 && !scroll.isDecelerating:
                    translate(dy: dy - lastY)
                    scroll.contentOffset.y = 0
                default:
                    break
                }
            }else{
                translate(dy: dy)
            }
        case .ended,
             .cancelled,
             .failed:
            if let scroll = scrollView{
                let minY = container!.frame.minY
                switch dragDirection(vel) {
                case .up where minY - minSheetPosition! > tolerance:
                    scroll.setContentOffset(lastContentOffset, animated: false)
                    self.finishDragging(with: vel, position: minY)
                default:
                    if !isSheetPosition(minY){
                        self.finishDragging(with: vel, position: minY)
                    }
                }
            }else{
                self.finishDragging(with: vel, position: container!.frame.minY + dy)
            }
        default: break
        }
        
        if let scroll = scrollView{
            lastY = dy
            lastContentOffset = scroll.contentOffset
        }else{
            recognizer.setTranslation(.zero, in: recognizer.view)
        }
    }
    
    /**
     Check if current top y position is one of the UBottomSheetCoordinatorDataSource#sheetPositions(availableHeight)
     
     - parameter point: current top y position
     */
    private func isSheetPosition(_ point: CGFloat) -> Bool{
        return dataSource.sheetPositions(availableHeight).first(where: { (p) -> Bool in
            abs(p - point) < tolerance
        }) != nil
    }
    
    /// Scroll view pan direction state: up, down or idle
    private enum DraggingState{
        case up, down, idle
    }
    
    /**
     Find the scroll pan direction; dragging up or down.
     
     - parameter velocity: draging velocity of scroll view recognizer
     */
    private func dragDirection(_ velocity: CGPoint) -> DraggingState{
        if velocity.y < 0 {
            return .up
        }else if velocity.y > 0{
            return .down
        }else{
            return .idle
        }
    }
    
    /**
     It helps when finishing dragging to the nearest sheet position in the direction of movement.
     
     i.e. for the given sheet positions ```[0.1, 0.5, 0.8].map{$0*availableHeight}``` if recognizer finishes while dragging up at  ```0.45*availableHeight``` the positions lower than 0.45 wiill be filtered and sheet will move to the ```0.1*availableHeight```.
     
     - parameter velocity: draging velocity of recognizer
     - parameter currentPosition: current top constraint value of container view
     */
    private func filteredPositions(_ velocity: CGPoint, currentPosition: CGFloat) -> [CGFloat]{
        if velocity.y < 100 { /// dragging up
            let data = dataSource.sheetPositions(availableHeight).filter { (p) -> Bool in
                p < currentPosition
            }
            
            if data.isEmpty{
                return dataSource.sheetPositions(availableHeight)
            }else{
                return data
            }
        }else if velocity.y > 100 { /// dragging down
            let data = dataSource.sheetPositions(availableHeight).filter { (p) -> Bool in
                p > currentPosition
            }
            if data.isEmpty{
                return dataSource.sheetPositions(availableHeight)
            }else{
                return data
            }
        }else{
            return dataSource.sheetPositions(availableHeight)
        }
    }
    
    /// y translation value for top rubber banding calculation
    private var totalTranslationMinY: CGFloat!
    ///  y translation value for bottom rubber banding calculation
    private var totalTranslationMaxY: CGFloat!
    
    /**
     Drives container view according the given value
     
     - parameter dy: change in the y direction of pan gesture
     */
    private func translate(dy: CGFloat){
        guard dy != 0 else {return}

        let topLimit = minSheetPosition!
        let bottomLimit = maxSheetPosition!
        
        let oldFrame = container!.frame
        var newY = oldFrame.minY
        
        if hasExceededTopLimit(oldFrame.minY, topLimit){
            totalTranslationMinY -= dy
            totalTranslationMaxY = maxSheetPosition!
            newY = dataSource.rubberBandLogicTop(totalTranslationMinY, topLimit)
        }else if hasExceededBottomLimit(oldFrame.minY, bottomLimit){
            totalTranslationMinY = minSheetPosition!
            totalTranslationMaxY += dy
            newY = dataSource.rubberBandLogicBottom(totalTranslationMaxY, bottomLimit)
        }else{
            totalTranslationMinY = minSheetPosition!
            totalTranslationMaxY = maxSheetPosition!
            newY += dy
        }

        let height = max(availableHeight - minSheetPosition!, availableHeight - newY)
        let f = CGRect(x: 0, y: newY, width: oldFrame.width, height: height)
        container?.frame = f

        self.delegate?.bottomSheet(self.container, didChange: .progressing(f.minY, calculatePercent(at: f.minY)))
    }
    
    /**
     Pan gesture finish event
     
     - parameter velocity: Pan gesture velocity
     - parameter position: new top constraint value
     */
    private func finishDragging(with velocity: CGPoint, position: CGFloat){
        let y = filteredPositions(velocity, currentPosition: position).nearest(to: position)
        endTranslate(to: y, animated: true)
    }
    
    //to ignore previous animation completion events
    private var lastAnimatedValue: CGFloat = 0.0
    
    /**
     Drives the view to the given position with animation option
     
     - parameter position: new top constraint value
     - parameter animated: Pass true to animate the y position change; otherwise pass false.
     */
    private func endTranslate(to position: CGFloat, animated: Bool = false){
        guard position != 0 else {return}
        let oldFrame = container!.frame
        let height = max(availableHeight - minSheetPosition!, availableHeight - position)
        let f = CGRect(x: 0, y: position, width: oldFrame.width, height: height)

        self.delegate?.bottomSheet(self.container, didChange: .willFinish(position, self.calculatePercent(at: position)))

        if animated{
            self.lastAnimatedValue = position
            dataSource.animator?.animate(animations: {
                self.delegate?.bottomSheet(self.container, finishTranslateWith: { (anim) in
                    anim(self.calculatePercent(at: position))
                })
                self.container!.frame = f
                self.parent.view.layoutIfNeeded()
            }, completion: { finished in
                if self.lastAnimatedValue != position {return}
                self.delegate?.bottomSheet(self.container, didChange: .finished(position, self.calculatePercent(at: position)))
                if position >= self.availableHeight{
                    self.removeSheet()
                }
            })
        }else{
            self.container!.frame = f
            self.delegate?.bottomSheet(self.container, didChange: .finished(position, self.calculatePercent(at: position)))
        }
    }
    
    //MARK: Utility functions
    
    /**
     Sheet translation in precent.
     
     Lowest top sheet y position is 100. Highest bottom sheet y position is 0 percent.
     
     - parameter pos: current top constraint value
     */
    private func calculatePercent(at pos: CGFloat) -> CGFloat{
        return (availableHeight - pos) / (availableHeight - minSheetPosition!) * 100
    }

    /**
     Top sheet position limit has exceeded while dragging
     
     - parameter constant: current top constraint value
     - parameter limit: min sheet y position
     */
    private func hasExceededTopLimit(_ constant: CGFloat, _ limit: CGFloat) -> Bool{
        return constant < limit
    }
    
    /**
     Bottom sheet position limit has exceeded while dragging
     
     - parameter constant: current top constraint value
     - parameter limit: max sheet y position
     */
    private func hasExceededBottomLimit(_ constant: CGFloat, _ limit: CGFloat) -> Bool{
        return constant > limit
    }
    
}
