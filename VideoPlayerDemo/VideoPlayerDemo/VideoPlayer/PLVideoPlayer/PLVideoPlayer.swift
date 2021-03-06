import UIKit
import PLPlayerKit

class PLVideoPlayer: NSObject {
    
    static let shared = PLVideoPlayer()
    
    /// 当前URL
    var url: URL? {
        return player?.url
    }
    
    /// 加载状态
    private(set) var loading: Bool = false {
        didSet {
            if loading {
                delegate { $0.videoPlayerLoadingBegin(self) }
            } else {
                delegate { $0.videoPlayerLoadingEnd(self) }
            }
        }
    }
    /// 播放状态
    private(set) var state: VideoPlayer.State = .stopped {
        didSet {
            switch state {
            case .playing:
                delegate { $0.videoPlayerPlaying(self) }
            case .paused:
                delegate { $0.videoPlayerPaused(self) }
            case .stopped:
                delegate { $0.videoPlayerStopped(self) }
            case .finish:
                delegate { $0.videoPlayerFinish(self) }
            case .error:
                delegate { $0.videoPlayerError(self) }
            }
        }
    }
    /// 音量 0 - 1
    var volume: Double = 1.0 {
        didSet { player?.setVolume(Float(volume)) }
    }
    /// 是否静音
    var isMuted: Bool = false {
        didSet {
            player?.isMute = isMuted
        }
    }
    /// 是否循环播放
    var isLoop: Bool = false {
        didSet {
            player?.loopPlay = isLoop
        }
    }
    /// 是否后台播放
    var isBackground: Bool = false
    /// 是否自动播放
    var isAutoPlay: Bool = true
    /// 播放信息 (锁屏封面)
    var playingInfo: VideoPlayerInfo? {
        didSet {
            guard let playingInfo = playingInfo else { return }
            
            playingInfo.set(self)
            add(delegate: playingInfo)
        }
    }
    
    var delegates: [DelegateBridge<AnyObject>] = []
    private lazy var playTimer: Timer = {
        let timer = Timer(timeInterval: 1.0,
                          target: self,
                          selector: #selector(timerAction),
                          userInfo: nil,
                          repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    } ()
    private var player: PLPlayer?
    private var playerView = VideoPlayerView(.none)
    private var userPaused: Bool = false
    private var seekCompletion: (() -> Void)?
    private var ready: Bool = false
    
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    private func pauseNoUser() {
        userPaused = false
        player?.pause()
    }
}

extension PLVideoPlayer {
    
    @objc func timerAction() {
        
        if let time = currentTime {
            delegate { $0.videoPlayer(self, updatedCurrent: time) }
        }
        
        if let time = totalTime {
            delegate { $0.videoPlayer(self, updatedTotal: time) }
        }
    }
    
    /// 会话线路变更通知
    @objc func sessionRouteChange(_ notification: NSNotification) {
        guard
            let info = notification.userInfo,
            let reason = info[AVAudioSessionRouteChangeReasonKey] as? Int else {
            return
        }
        guard let _ = player else { return }
        
        switch AVAudioSession.RouteChangeReason(rawValue: UInt(reason)) {
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
        guard let _ = player else { return }
        
        switch AVAudioSession.InterruptionType(rawValue: UInt(type)) {
        case .began?:
            if !userPaused, state == .playing { pauseNoUser() }
        case .ended?:
            if !userPaused, state == .paused { play() }
        case .none: break
        }
    }
}

extension PLVideoPlayer {
    
    /// 清理
    private func clear() {
        ready = false
        player?.stop()
        playingInfo = nil
        VideoPlayer.removeAudioSession()
    }
    
    /// 错误
    private func error() {
        clear()
        loading = false
        state = .error
    }
}

extension PLVideoPlayer: PLPlayerDelegate {
    /*
     PLPlayerStatusUnknow    初始化时指定的状态，不会有任何状态会跳转到这一状态
     PLPlayerStatusPreparing    播放器正在准备当中
     PLPlayerStatusReady    播放器准备完成的状态
     PLPlayerStatusOpen    播放器准备开始连接的状态
     PLPlayerStatusCaching    播放器正在缓存的状态
     PLPlayerStatusPlaying    播放器正在播放的状态
     PLPlayerStatusPaused    播放器暂停的状态
     PLPlayerStatusStopped    播放器播放结束或手动停止的状态
     PLPlayerStatusError    播放器出现错误的状态
     PLPlayerStateAutoReconnecting    播放器开始自动重连
     PLPlayerStatusCompleted    点播播放完成
     */
    func player(_ player: PLPlayer, statusDidChange state: PLPlayerStatus) {
        switch state {
        case .statusPreparing:
            // 播放器正在准备当中
            print("播放器正在准备当中")
            loading = true
            
        case .statusCaching:
            // 播放器正在缓存的状态
            print("缓存状态")
            loading = true
            
        case .statusReady:
            print("准备完成")
            loading = false
            
        case .statusOpen:
            print("开始连接")
            loading = false
           
        case .statusPlaying:
            // 播放器正在播放的状态
            print("开始播放")
            loading = false
            
            if !ready {
                if isAutoPlay {
                    self.playTimer.fireDate = Date()
                    self.userPaused = false
                    self.state = .playing
                    player.play()
                    
                } else {
                    self.userPaused = true
                    self.state = .paused
                    player.pause()
                }
                ready = true
                delegate { $0.videoPlayerReady(self) }
            }
            
        case .statusPaused:
            // 播放器暂停的状态
            print("暂停播放")
            if !userPaused {
                self.state = .paused
            }
        case .statusError:
            // 播放器错误的状态
            print("播放错误")
            player.play()
            
        case .stateAutoReconnecting:
            // 播放器开始自动重连
            loading = true
            self.state = .playing
            
        case .statusCompleted:
            loading = false
            self.state = .finish
            
        default: break
        }
    }
    
    func player(_ player: PLPlayer, stoppedWithError error: Error?) {
        state = .error
    }
    
    func player(_ player: PLPlayer, loadedTimeRange timeRange: CMTime) {
        // 加载
        guard let totalTime = totalTime else { return }
        // 本次缓冲时间范围
        let start = 0.0
        // 缓冲总时长
        let duration = timeRange.seconds
        // 缓冲进度
        let progress = (duration - start) / totalTime
        
        print("""
            ==========pl===========
            duration \(duration)
            totalDuration \(totalTime)
            progress \(progress)\n
            """)
        
        delegate { $0.videoPlayer(self, updatedBuffer: progress) }
    }
    
    func player(_ player: PLPlayer, seekToCompleted isCompleted: Bool) {
        // 恢复监听
        delegate { $0.videoPlayerSeekFinish(self) }
        seekCompletion?()
        seekCompletion = nil
        loading = false
    }
    
    func playerWillBeginBackgroundTask(_ player: PLPlayer) {
        defer {
            playTimer.fireDate = .distantFuture
        }
        guard let _ = player.playerView else { return }
        guard !isBackground else { return }
        
        if !userPaused, state == .playing { pauseNoUser() }
    }
    
    func playerWillEndBackgroundTask(_ player: PLPlayer) {
        defer {
            playTimer.fireDate = Date()
        }
        guard let _ = player.playerView else { return }
        guard !isBackground else { return }
        
        if !userPaused, state == .paused { play() }
    }
}

extension PLVideoPlayer: PlayerDelagetes {
    typealias Element = VideoPlayerDelagete
}

extension PLVideoPlayer: VideoPlayerable {
    
    @discardableResult
    func prepare(url: URL) -> VideoPlayerView {

        clear()
        
        guard
            let player = PLPlayer(url: url, option: PLPlayerOption.default()),
            let view = player.playerView else {
            state = .error
            return VideoPlayerView(.none)
        }
        
        player.delegate = self
        player.isBackgroundPlayEnable = true
        player.loopPlay = isLoop
        player.setVolume(Float(volume))
        player.isMute = isMuted
        self.player = player
        playerView = VideoPlayerView(.pl(view))
        playerView.backgroundColor = .clear
        playerView.contentMode = .scaleAspectFit
        
        playTimer.fireDate = Date()
        
        state = .stopped
        loading = true
        
        // 设置音频会话
        VideoPlayer.setupAudioSession()
        
        player.play()
        
        return playerView
    }
    
    func play() {
        guard ready else { return }
        
        playTimer.fireDate = Date()
        userPaused = false
        state = .playing
        player?.resume()
    }
    
    func pause() {
        guard ready else { return }
        
        userPaused = true
        state = .paused
        player?.pause()
    }
    
    func stop() {
        clear()
        loading = false
        playTimer.fireDate = .distantFuture
        state = .stopped
    }
    
    func seek(to time: TimeInterval, completion: @escaping (() -> Void)) {
        guard ready else { return }
        guard
            let player = player,
            player.status == .statusCaching ||
            player.status == .statusPlaying ||
            player.status == .statusPaused else {
            completion()
            return
        }
        guard seekCompletion == nil else {
            completion()
            return
        }
        
        loading = true
        player.seek(to: CMTimeMakeWithSeconds(time, preferredTimescale: 1))
        seekCompletion = completion
    }
    
    var currentTime: TimeInterval? {
        guard let duration = player?.currentTime else { return nil }
        
        let time = duration.seconds
        return time.isNaN ? nil : time
    }
    
    var totalTime: TimeInterval? {
        guard let duration = player?.totalDuration else { return nil }
        
        let time = duration.seconds
        return time.isNaN ? nil : time
    }
    
    var currentRate: Double {
        return player?.playSpeed ?? 0.0
    }
    
    var view: VideoPlayerView {
        return playerView
    }
}
