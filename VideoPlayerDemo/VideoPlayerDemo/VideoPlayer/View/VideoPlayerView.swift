import UIKit
import AVKit

class VideoPlayerView: UIView {
    
    enum Mode {
        case none
        case pl(UIView)
        case av(AVPlayerLayer)
    }
    
    private let mode: Mode
    
    init(_ mode: Mode) {
        self.mode = mode
        super.init(frame: .zero)
        
        switch mode {
        case .pl(let view):
            addSubview(view)
            
        case .av(let layer):
            self.layer.addSublayer(layer)
            
        default: break
        }
        
        clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var contentMode: UIView.ContentMode {
        get {
            return super.contentMode
        }
        set {
            super.contentMode = newValue
            switch mode {
            case .pl(let view):
                view.contentMode = newValue
                
            case .av(let layer):
                switch newValue {
                case .scaleToFill:
                    layer.videoGravity = .resize
                case .scaleAspectFit:
                    layer.videoGravity = .resizeAspect
                case .scaleAspectFill:
                    layer.videoGravity = .resizeAspectFill
                default:
                    layer.videoGravity = .resizeAspectFill
                }
                
            default: break
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        switch mode {
        case .pl(let view):
            view.frame = bounds
            
        case .av(let layer):
            if let animation = layer.animation(forKey: "bounds.size") {
                CATransaction.begin()
                CATransaction.setAnimationDuration(animation.duration)
                CATransaction.setAnimationTimingFunction(animation.timingFunction)
                layer.frame = bounds
                CATransaction.commit()
            } else {
                layer.frame = bounds
            }
            
        default: break
        }
    }
}
