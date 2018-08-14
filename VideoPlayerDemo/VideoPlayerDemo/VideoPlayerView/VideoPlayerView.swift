//
//  VideoPlayerView.swift
//  VideoPlayerDemo
//
//  Created by 李响 on 2018/6/1.
//  Copyright © 2018年 李响. All rights reserved.
//

import UIKit

class VideoPlayerView: UIView {
    
    typealias ControlView = UIView & VideoPlayerControlViewable
    
    lazy var playingView: UIView = {
        $0.backgroundColor = .black
        return $0
    }( UIView() )
    
    private weak var controlView: ControlView?
    private weak var finishView: UIView?
    private weak var errorView: UIView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setup()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        playingView.frame = bounds
    }
    
    private func setup() {
        addSubview(playingView)
    }
}

extension VideoPlayerView {
    
    func play(url: URL) {
        VideoPlayer.shared.add(delegate: self)
        let layer = VideoPlayer.shared.prepare(url: url)
        layer.frame = playingView.bounds
        playingView.layer.addSublayer(layer)
    }
    
    func stop() {
        VideoPlayer.shared.stop()
        VideoPlayer.shared.remove(delegate: self)
    }
    
    func resetLayer() {
        let layer = VideoPlayer.shared.layer()
        layer.frame = playingView.bounds
        playingView.layer.addSublayer(layer)
    }
}

extension VideoPlayerView {
    
    func set(controlView: ControlView) {
        self.controlView = controlView
        controlView.set(delegate: self)
    }
    
    func set(finishView: UIView) {
        finishView.isHidden = true
        self.finishView = finishView
    }
    
    func set(errorView: UIView) {
        errorView.isHidden = true
        self.errorView = errorView
    }
}

extension VideoPlayerView: VideoPlayerDelegate {
    
    func loadingBegin() {
        controlView?.loadingBegin()
    }
    func loadingEnd() {
        controlView?.loadingEnd()
    }
    
    func playing() {
        controlView?.set(state: true)
    }
    
    func paused() {
        controlView?.set(state: false)
    }
    
    func stopped() {
        
    }
    
    func finish() {
        finishView?.isHidden = false
        errorView?.isHidden = true
    }
    
    func error() {
        finishView?.isHidden = true
        errorView?.isHidden = false
    }
    
    func updated(bufferProgress progress: Float) {
        controlView?.set(buffer: progress, animated: true)
    }
    
    func updated(totalTime time: Float64) {
        controlView?.set(total: time)
    }
    
    func updated(currentTime time: Float64) {
        controlView?.set(current: time)
    }
    
    func seekFinish() {
        
    }
}

extension VideoPlayerView: VideoPlayerControlViewDelegate {
    
    func controlPlay() {
        VideoPlayer.shared.play()
    }
    
    func controlPause() {
        VideoPlayer.shared.pause()
    }
    
    func controlSeek(time: Float) {
        VideoPlayer.shared.seekTo(time: Float64(time))
    }
}
