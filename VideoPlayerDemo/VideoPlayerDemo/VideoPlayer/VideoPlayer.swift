//
//  VideoPlayer.swift
//
//  Created by 李响 on 2018/4/8.
//  Copyright © 2018年 lee. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
import MediaPlayer.MPRemoteCommandCenter

protocol VideoPlayerDelegate: AnyObject {
    /// 播放中
    func playing()
    /// 加载开始
    func loadingBegin()
    /// 加载结束
    func loadingEnd()
    /// 暂停
    func paused()
    /// 停止
    func stopped()
    /// 播放完成
    func finish()
    /// 播放错误
    func error()
    /// 更新缓冲进度
    func updated(bufferProgress: Float)
    /// 更新总时间 (秒)
    func updated(totalTime: Float64)
    /// 更新当前时间 (秒)
    func updated(currentTime: Float64)
    /// 跳转完成
    func seekFinish()
}

extension VideoPlayerDelegate {
    
    func playing() { }
    func loadingBegin() { }
    func loadingEnd() { }
    func paused() { }
    func stopped() { }
    func finish() { }
    func error() { }
    func updated(bufferProgress: Float) { }
    func updated(totalTime: Float64) { }
    func updated(currentTime: Float64) { }
    func seekFinish() { }
}

class VideoPlayer: NSObject {
    
    enum State {
        case playing
        case paused
        case stopped
        case error
    }
    
    static let shared = VideoPlayer()
    
    let playingInfo = VideoPlayerInfo()
    
    var volume: Float = 0.0 {
        didSet { player.volume = volume }
    }
    
    var isLoop: Bool = false
    var isBackground: Bool = false
    
    var delegates: [DelegateBridge<AnyObject>] = []
    
    private lazy var player = AVPlayer()
    private lazy var playerLayer = AVPlayerLayer(player: player)
    
    private var playerTimeObserver: Any?
    private var userPaused: Bool = false
    private var loading: Bool = false
    private var state: State = .stopped
    
    private let kvo_item_status = "status"
    private let kvo_item_duration = "duration"
    private let kvo_item_loadedTimeRanges = "loadedTimeRanges"
    private let kvo_item_playbackLikelyToKeepUp = "playbackLikelyToKeepUp"
    
    override init() {
        super.init()
        
        setup()
        setupNotification()
        setupRemoteCommand()
    }
    
    private func setup() {
        add(delegate: playingInfo)
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

extension VideoPlayer {
    
    /// 准备
    ///
    /// - Parameter url: url
    /// - Returns: AVPlayerLayer
    @discardableResult
    func prepare(url: URL) -> AVPlayerLayer {
        
        clear()
        
        let item = AVPlayerItem(url: url)
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        player.volume = volume
        if #available(iOS 10.0, *) {
            player.automaticallyWaitsToMinimizeStalling = false
        }
        
        addObserver()
        addObserver(item: item)
        addRemoteCommand()
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.masksToBounds = true
        
        state = .stopped
        loading = true
        delegate { $0.loadingBegin() }
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
        DispatchQueue.global().async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(AVAudioSessionCategoryPlayback)
                try session.setActive(true)
            } catch {
                print("音频会话创建失败")
            }
        }
        
        return playerLayer
    }
    
    /// 播放
    func play() {
        guard player.currentItem?.status == .readyToPlay else { return }
        
        player.play()
        state = .playing
        userPaused = false
        delegate { $0.playing() }
    }
    
    /// 暂停
    func pause(user: Bool = true) {
        player.pause()
        userPaused = user
        state = .paused
        delegate { $0.paused() }
    }
    
    /// 停止
    func stop() {
        clear()
        resetLoading()
        state = .stopped
        delegate { $0.stopped() }
    }
    
    /// 调到播放时间
    func seekTo(time: Float64, completion: (()->Void)? = nil) {
        guard player.status == .readyToPlay else { return }
        guard let item = player.currentItem else { return }
        
        let state = self.state
        if state == .playing { player.pause() }
        
        // 暂时移除监听
        removeObserver()
        
        let changeTime = CMTimeMakeWithSeconds(time, 1)
        item.seek(to: changeTime, completionHandler: { [weak self] (finish) in
            guard finish else { return }
            
            if state == .playing { self?.player.play() }
            
            // 恢复监听
            self?.addObserver()
            
            self?.delegate{ $0.seekFinish() }
            completion?()
        })
    }
    
    
    /// layer
    func layer() -> AVPlayerLayer {
        return playerLayer
    }
    /// 总时长 (秒)
    func totalTime() -> Float64? {
        guard let item = player.currentItem else { return nil }
        let time = CMTimeGetSeconds(item.duration)
        return time.isNaN ? nil : time
    }
    /// 当前播放时间 (秒)
    func currentTime() -> Float64? {
        guard let item = player.currentItem else { return nil }
        let time = CMTimeGetSeconds(item.currentTime())
        return time.isNaN ? nil : time
    }
    /// 当前状态
    ///
    /// - Returns: 状态
    func currentState() -> State {
        return state
    }
    /// 加载状态
    ///
    /// - Returns: true 加载中 false 未加载
    func loadingState() -> Bool {
        return loading
    }
    /// 当前速率
    ///
    /// - Returns: 速率
    func currentRate() -> Float {
        return player.rate
    }
}

extension VideoPlayer {
    
    /// 重置loading状态
    private func resetLoading() {
        guard loading else { return }
        
        loading = false
        delegate { $0.loadingEnd() }
    }
    
    /// 错误
    private func error() {
        clear()
        resetLoading()
        state = .error
        delegate { $0.error() }
    }
    
    /// 清理
    private func clear() {
        guard let item = player.currentItem else { return }
        
        player.pause()
        
        // 移除监听
        removeObserver()
        removeObserver(item: item)
        removeRemoteCommand()
        
        // 移除item
        player.replaceCurrentItem(with: nil)
        
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
                    print(player.error?.localizedDescription ?? "无法获取错误信息")
                    error()
                }
                
            case kvo_item_duration:
                // 获取总时长
                if let totalTime = totalTime() {
                    delegate { $0.updated(totalTime: totalTime) }
                }
                
            case kvo_item_loadedTimeRanges:
                // 加载
                guard let timeRange = item.loadedTimeRanges.first as? CMTimeRange else { return }
                guard let totalTime = totalTime() else { return }
                // 本次缓冲时间范围
                let start = Float(CMTimeGetSeconds(timeRange.start))
                let duration = Float(CMTimeGetSeconds(timeRange.duration))
                // 缓冲总时长
                let totalBuffer = TimeInterval(start + duration)
                // 缓冲进度
                let progress = Float(totalBuffer) / Float(totalTime)
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

extension VideoPlayer {
    
    /// 播放结束通知
    @objc func itemDidPlayToEndTime(_ notification: NSNotification) {
        seekTo(time: 0.0) {
            self.delegate { $0.updated(currentTime: 0.0) }
            guard !self.isLoop else { return }
            self.delegate { $0.finish() }
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
                self.pause(user: false)
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
            if !userPaused, state == .playing { pause(user: false) }
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
        if !userPaused, state == .playing { pause(user: false) }
    }
}

extension VideoPlayer {
    
    /// 设置远程控制
    private func setupRemoteCommand() {
        let remote = MPRemoteCommandCenter.shared()
        remote.playCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            switch self.state {
            case .playing: break
            case .paused: self.play()
            case .error, .stopped: return .noSuchContent
            }
            return .success
        }
        remote.pauseCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            switch self.state {
            case .playing: self.pause()
            case .paused: break
            case .error, .stopped: return .noSuchContent
            }
            return .success
        }
    }
    /// 添加远程控制
    private func addRemoteCommand() {
        let remote = MPRemoteCommandCenter.shared()
        remote.playCommand.isEnabled = true // 播放控制
        remote.pauseCommand.isEnabled = true // 暂停控制
    }
    /// 移除远程控制
    private func removeRemoteCommand() {
        let remote = MPRemoteCommandCenter.shared()
        remote.playCommand.isEnabled = false // 播放控制
        remote.pauseCommand.isEnabled = false // 暂停控制
    }
}

extension VideoPlayer: VideoPlayerDelegates {
    typealias T = VideoPlayerDelegate
}
