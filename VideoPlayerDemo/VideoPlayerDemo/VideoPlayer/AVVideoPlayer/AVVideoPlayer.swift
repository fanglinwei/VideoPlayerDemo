import UIKit
import Foundation
import AVFoundation

class AVVideoPlayer: NSObject {
        
    static let shared = AVVideoPlayer()
    
    /// 加载状态
    private(set) var loading: Bool = false {
        didSet {
            if loading {
                delegate { $0.loadingBegin() }
            } else {
                delegate { $0.loadingEnd() }
            }
        }
    }
    /// 播放状态
    private (set) var state: VideoPlayer.State = .stopped {
        didSet {
            switch state {
            case .playing:
                delegate { $0.playing() }
            case .paused:
                delegate { $0.paused() }
            case .stopped:
                delegate { $0.stopped() }
            case .finish:
                delegate { $0.finish() }
            case .error:
                delegate { $0.error() }
            }
        }
    }
    /// 音量 0 - 1
    var volume: Double = 1.0 {
        didSet { player.volume = Float(volume)}
    }
    /// 是否静音
    var isMuted: Bool = false {
        didSet {
            player.isMuted = isMuted
        }
    }
    /// 是否循环播放
    var isLoop: Bool = false
    /// 是否后台播放
    var isBackground: Bool = false
    /// 播放信息 (锁屏封面和远程控制)
    var playingInfo: VideoPlayerInfo? {
        didSet {
            guard let playingInfo = playingInfo else { return }
            
            playingInfo.set(self)
            add(delegate: playingInfo)
        }
    }
    
    var delegates: [DelegateBridge<AnyObject>] = []
    private lazy var player = AVPlayer()
    private lazy var playerLayer = AVPlayerLayer(player: player)
    private lazy var playerView: VideoPlayerView = VideoPlayerView(.av(playerLayer))
    
    private var playerTimeObserver: Any?
    private var userPaused: Bool = false
    private var isSeeking: Bool = false
    
    private let kvo_item_status = "status"
    private let kvo_item_duration = "duration"
    private let kvo_item_loadedTimeRanges = "loadedTimeRanges"
    private let kvo_item_playbackLikelyToKeepUp = "playbackLikelyToKeepUp"
    
    override init() {
        super.init()
        
        setup()
        setupNotification()
    }
    
    private func setup() {
        volume = 1.0
        isMuted = false
        isLoop = false
        isBackground = false
    }
    
    private func setupNotification() {
        
        NotificationCenter.default.addObserver(self, selector: #selector(itemDidPlayToEndTime(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(itemPlaybackStalled(_:)), name: .AVPlayerItemPlaybackStalled, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRouteChange(_:)), name: .AVAudioSessionRouteChange, object: AVAudioSession.sharedInstance())
        
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruption(_:)), name: .AVAudioSessionInterruption, object: AVAudioSession.sharedInstance())
        
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: .UIApplicationWillEnterForeground, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground(_:)), name: .UIApplicationDidEnterBackground, object: nil)
    }
}

extension AVVideoPlayer {
    
    private func pauseNoUser() {
        player.pause()
        userPaused = false
        state = .paused
    }
}

extension AVVideoPlayer {
    
    /// 重置loading状态
    private func resetLoading() {
        guard loading else { return }
        
        loading = false
    }
    
    /// 错误
    private func error() {
        clear()
        resetLoading()
        state = .error
    }
    
    /// 清理
    private func clear() {
        guard let item = player.currentItem else { return }
        
        player.pause()
        
        // 移除监听
        removeObserver()
        removeObserver(item: item)
        
        // 移除item
        player.replaceCurrentItem(with: nil)
        playingInfo = nil
        
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
    
    private func addObserver() {
        removeObserver()
        // 当前播放时间 (间隔: 每秒10次)
        let interval = CMTime(value: 1, timescale: 10)
        playerTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
            [weak self] (time) in
            let time = CMTimeGetSeconds(time)
            self?.delegate{ $0.updated(currentTime: time) }
        }
    }
    private func removeObserver() {
        guard let observer = playerTimeObserver else { return }
        playerTimeObserver = nil
        player.removeTimeObserver(observer)
    }
    
    private func addObserver(item: AVPlayerItem) {
        let options: NSKeyValueObservingOptions = [.new, .old]
        item.addObserver(self, forKeyPath: kvo_item_status, options: options, context: nil)
        item.addObserver(self, forKeyPath: kvo_item_duration, options: options, context: nil)
        item.addObserver(self, forKeyPath: kvo_item_loadedTimeRanges, options: options, context: nil)
        item.addObserver(self, forKeyPath: kvo_item_playbackLikelyToKeepUp, options: options, context: nil)
    }
    private func removeObserver(item: AVPlayerItem) {
        item.removeObserver(self, forKeyPath: kvo_item_status)
        item.removeObserver(self, forKeyPath: kvo_item_duration)
        item.removeObserver(self, forKeyPath: kvo_item_loadedTimeRanges)
        item.removeObserver(self, forKeyPath: kvo_item_playbackLikelyToKeepUp)
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard let change = change else { return }
        guard let new = change[.newKey] else { return }
        guard let old = change[.oldKey] else { return }
        
        if let item = object as? AVPlayerItem {
            
            switch keyPath {
            case kvo_item_status:
                // 状态 (判断是否新的与旧的相同 神奇的BUG)
                guard let new = new as? Int else { return }
                guard let old = old as? Int else { return }
                guard new != old else { return }
                switch AVPlayerItemStatus(rawValue: new) ?? .unknown {
                case .unknown: break
                case .readyToPlay:
                    // 播放
                    play()
                    
                case .failed:
                    // 异常
                    print(item.error?.localizedDescription ?? "无法获取错误信息")
                    error()
                }
                
            case kvo_item_duration:
                // 获取总时长
                if let totalTime = totalTime {
                    delegate { $0.updated(totalTime: totalTime) }
                }
                
            case kvo_item_loadedTimeRanges:
                // 加载
                guard let timeRange = item.loadedTimeRanges.first as? CMTimeRange else { return }
                guard let totalTime = totalTime else { return }
                // 本次缓冲时间范围
                let start = timeRange.start.seconds
                let duration = timeRange.duration.seconds
                // 缓冲总时长
                let totalBuffer = start + duration
                // 缓冲进度
                let progress = totalBuffer / totalTime
                
                print("""
                    ==========av===========
                    duration \(totalBuffer)
                    totalDuration \(totalTime)
                    progress \(progress)\n
                    """)
                delegate { $0.updated(bufferProgress: progress) }
                
            case kvo_item_playbackLikelyToKeepUp:
                // 缓存是否可以播放
                guard let isKeep = new as? Bool else { return }
                
                if isKeep {
                    loading = false
                    delegate{ $0.loadingEnd() }
                } else {
                    loading = true
                    delegate{ $0.loadingBegin() }
                }
                
            default: break
            }
        }
    }
}

extension AVVideoPlayer {
    
    /// 播放结束通知
    @objc func itemDidPlayToEndTime(_ notification: NSNotification) {
        pause()
        seek(to: 0.0) { [weak self] in
            guard let this = self else { return }
            if this.isLoop {
                this.delegate { $0.updated(currentTime: 0.0) }
                this.play()
            } else {
                this.state = .finish
            }
        }
    }
    
    /// 播放异常通知
    @objc func itemPlaybackStalled(_ notification: NSNotification) {
        if state == .playing { play() }
    }
    
    /// 会话线路变更通知
    @objc func sessionRouteChange(_ notification: NSNotification) {
        guard
            let info = notification.userInfo,
            let reason = info[AVAudioSessionRouteChangeReasonKey] as? Int else {
            return
        }
        guard let _ = player.currentItem else { return }
        
        switch AVAudioSessionRouteChangeReason(rawValue: UInt(reason)) {
        case .oldDeviceUnavailable?:
            DispatchQueue.main.async {
                self.pauseNoUser()
            }
        default: break
        }
    }
    
    /// 会话中断通知
    @objc func sessionInterruption(_ notification: NSNotification) {
        guard
            let info = notification.userInfo,
            let type = info[AVAudioSessionInterruptionTypeKey] as? Int else {
            return
        }
        guard let _ = player.currentItem else { return }
        
        switch AVAudioSessionInterruptionType(rawValue: UInt(type)) {
        case .began?:
            if !userPaused, state == .playing { pauseNoUser() }
        case .ended?:
            if !userPaused, state == .paused { play() }
        case .none: break
        }
    }
    
    @objc func willEnterForeground(_ notification: NSNotification) {
        guard let _ = player.currentItem else { return }
        guard !isBackground else {
            // 恢复layer的播放器
            playerLayer.player = player
            return
        }
        if !userPaused, state == .paused { play() }
    }
    
    @objc func didEnterBackground(_ notification: NSNotification) {
        guard let _ = player.currentItem else { return }
        guard !isBackground else {
            // 后台播放模式时 移除layer的播放器 停止渲染 只播放音频
            playerLayer.player = nil
            return
        }
        if !userPaused, state == .playing { pauseNoUser() }
    }
}

extension AVVideoPlayer: VideoPlayerable {
    
    @discardableResult
    func prepare(url: URL) -> VideoPlayerView {
        
        clear()
        
        let item = AVPlayerItem(url: url)
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        player.volume = Float(volume)
        player.isMuted = isMuted
        
        if #available(iOS 10.0, *) {
            player.automaticallyWaitsToMinimizeStalling = false
        }
        
        addObserver()
        addObserver(item: item)
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.masksToBounds = true

        loading = true
        state = .stopped
        
        playerView = VideoPlayerView(.av(playerLayer))
        
        // 设置音频会话
        VideoPlayer.setupAudioSession()
        
        return playerView
    }
    
    func play() {
        guard player.currentItem?.status == .readyToPlay else { return }
        
        player.play()
        userPaused = false
        state = .playing
    }
    
    func pause() {
        player.pause()
        userPaused = true
        state = .paused
    }
    
    func stop() {
        clear()
        resetLoading()
        state = .stopped
    }
    
    func seek(to time: TimeInterval, completion: @escaping (() -> Void)) {
        guard
            let item = player.currentItem,
            player.status == .readyToPlay,
            !isSeeking else {
            completion()
            return
        }
        
        let state = self.state
        if state == .playing { player.pause() }
        
        // 暂时移除监听
        removeObserver()
        isSeeking = true
        
        let changeTime = CMTimeMakeWithSeconds(time, 1)
        item.seek(to: changeTime, completionHandler: { [weak self] (finish) in
            guard let this = self else { return }
            
            if state == .playing { this.player.play() }
            
            // 恢复监听
            this.addObserver()
            this.isSeeking = false
            this.delegate{ $0.seekFinish() }
            completion()
        })
    }
    
    var currentTime: TimeInterval? {
        
        guard let item = player.currentItem else { return nil }
        let time = CMTimeGetSeconds(item.currentTime())
        return time.isNaN ? nil : time
    }
    
    var totalTime: TimeInterval? {
        guard let item = player.currentItem else { return nil }
        let time = CMTimeGetSeconds(item.duration)
        return time.isNaN ? nil : time
    }
    
    var currentRate: Double {
        return Double(player.rate)
    }
    
    var view: VideoPlayerView {
        return playerView
    }
}

extension AVVideoPlayer: PlayerDelagetes  {
    
    typealias Element = VideoPlayerDelagete
}

