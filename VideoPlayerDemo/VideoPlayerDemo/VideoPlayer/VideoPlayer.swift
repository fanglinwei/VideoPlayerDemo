import Foundation
import UIKit
import AVFoundation

enum VideoPlayer {
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
}

extension VideoPlayer {
    
    static let av: Builder = .init { AVVideoPlayer() }
    
    static let pl: Builder = .init { PLVideoPlayer() }
}

extension VideoPlayer {
    
    static func setupAudioSession() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        DispatchQueue.global().async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true, options: [.notifyOthersOnDeactivation])
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
                try session.setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                print("音频会话创建失败")
            }
        }
    }
}

extension VideoPlayer {
    
    class Builder {
        
        typealias Generator = () -> VideoPlayerable
        
        private var generator: Generator
        
        private(set) lazy var shared = generator()
        
        init(_ generator: @escaping Generator) {
            self.generator = generator
        }
        
        func instance() -> VideoPlayerable {
            return generator()
        }
    }
}
