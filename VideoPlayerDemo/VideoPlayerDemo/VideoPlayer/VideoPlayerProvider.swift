import UIKit

class VideoPlayerProvider: NSObject {
    
    typealias ControlView = UIView & VideoPlayerControlViewable
    typealias FinishView = UIView & VideoPlayerFinishViewable
    typealias ErrorView = UIView & VideoPlayerErrorViewable
    typealias CoverView = UIView & VideoPlayerCoverViewable
    
    private weak var player: VideoPlayerable?
    
    private let controlView: ControlView
    private let finishView: FinishView
    private let errorView: ErrorView
    private let coverView: CoverView
    private let playHandle: (() -> Void)
    
    init(control: ControlView,
         finish: FinishView,
         error: ErrorView,
         cover: CoverView,
         playHandle handle: @escaping (() -> Void)) {
        
        controlView = control
        finishView = finish
        errorView = error
        coverView = cover
        playHandle = handle
        super.init()
        
        controlView.isHidden = true
        controlView.set(delegate: self)
        
        finishView.isHidden = true
        finishView.set(delegate: self)
        
        errorView.isHidden = true
        errorView.set(delegate: self)
        
        coverView.isHidden = true
        coverView.set(delegate: self)
    }
}

extension VideoPlayerProvider {
    
    /// 设置播放器
    ///
    /// - Parameter player: 播放器
    func set(player: VideoPlayerable?) {
        defer {
            self.player?.remove(delegate: self)
            self.player = player
            player?.add(delegate: self)
        }
        guard let player = player else {
            return
        }
        
        switch player.state {
        case .playing:  playing()
        case .paused:   paused()
        case .stopped:  stopped()
        case .finish:   finish()
        case .error:    error()
        }
    }
}

extension VideoPlayerProvider: VideoPlayerDelagete {
    
    func loadingBegin() {
        controlView.loadingBegin()
    }
    func loadingEnd() {
        controlView.loadingEnd()
    }
    
    func playing() {
        controlView.set(state: true)
        controlView.isHidden = false
        finishView.isHidden = true
        errorView.isHidden = true
        coverView.isHidden = true
    }
    
    func paused() {
        controlView.set(state: false)
        controlView.isHidden = false
        finishView.isHidden = true
        errorView.isHidden = true
        coverView.isHidden = true
    }
    
    func stopped() {
        controlView.isHidden = true
        finishView.isHidden = true
        errorView.isHidden = true
        coverView.isHidden = false
    }
    
    func finish() {
        controlView.isHidden = true
        finishView.isHidden = false
        errorView.isHidden = true
        coverView.isHidden = true
    }
    
    func error() {
        controlView.isHidden = true
        finishView.isHidden = true
        errorView.isHidden = false
        coverView.isHidden = true
    }
    
    func updated(bufferProgress progress: Double) {
        controlView.set(buffer: progress, animated: true)
    }
    
    func updated(totalTime time: TimeInterval) {
        controlView.set(total: time)
    }
    
    func updated(currentTime time: TimeInterval) {
        controlView.set(current: time)
    }
    
    func seekFinish() {
        
    }
}

extension VideoPlayerProvider: VideoPlayerControlViewDelegate {
    
    func controlPlay() {
        player?.play()
    }
    
    func controlPause() {
        player?.pause()
    }
    
    func controlSeek(time: Double, completion: @escaping (()->Void)) {
        player?.seek(to: time, completion: completion)
    }
}

extension VideoPlayerProvider: VideoPlayerFinishViewDelegate {
    
    func finishReplay() {
        player?.play()
    }
}

extension VideoPlayerProvider: VideoPlayerErrorViewDelegate {
    
    func errorRetry() {
        player?.play()
    }
}

extension VideoPlayerProvider: VideoPlayerCoverViewDelegate {
    
    func play() {
        playHandle()
        coverView.isHidden = true
    }
}
