import Foundation
import UIKit
import AVFoundation

enum VideoPlayer {
    case av
    case pl
    
    /// 播放状态
    enum State {
        /// 播放中
        case playing
        /// 已暂停
        case paused
        /// 停止
        case stopped
        /// 播放完成
        case finish
        /// 播出出错
        case error
    }
    
    static func shared(_ mode: VideoPlayer = .av) -> VideoPlayerable {
        switch mode {
        case .av:
            return AVVideoPlayer.shared
        case .pl:
            return PLVideoPlayer.shared
        }
    }
    
    static func instance(_ mode: VideoPlayer = .av) -> VideoPlayerable {
        switch mode {
        case .av:
            return AVVideoPlayer()
        case .pl:
            return PLVideoPlayer()
        }
    }
}

extension VideoPlayer {
    
    static func setupAudioSession() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        DispatchQueue.global().async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
            } catch {
                print("音频会话创建失败")
            }
        }
    }
    
    static func removeAudioSession() {
        UIApplication.shared.endReceivingRemoteControlEvents()
        DispatchQueue.global().async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .moviePlayback)
                try session.setActive(false)
            } catch {
                print("音频会话创建失败")
            }
        }
    }
}
