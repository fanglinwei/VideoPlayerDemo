//
//  VideoPlayerInfo.swift
//
//  Created by 李响 on 2018/5/29.
//  Copyright © 2018年 LiveTrivia. All rights reserved.
//

import MediaPlayer.MPNowPlayingInfoCenter

class VideoPlayerInfo: VideoPlayerDelegate {
    
    /// 设置播放信息
    ///
    /// - Parameters:
    ///   - title: 标题
    ///   - artist: 作者
    ///   - thumb: 封面
    ///   - url: 链接
    func setupPlayingInfo(title: String, artist: String, thumb: UIImage, url: URL) {
        var info: [String : Any] = [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        
        if #available(iOS 10.3, *) {
            // 当前URL
            info[MPNowPlayingInfoPropertyAssetURL] = url
        }
        
        if #available(iOS 10.0, *) {
            // 封面图
            let artwork = MPMediaItemArtwork(
                boundsSize: thumb.size,
                requestHandler: { (size) -> UIImage in
                    return thumb
            })
            info[MPMediaItemPropertyArtwork] = artwork
            // 媒体类型
            info[MPNowPlayingInfoPropertyMediaType] = NSNumber(value: MPNowPlayingInfoMediaType.video.rawValue)
        } else {
            // 封面图
            let artwork = MPMediaItemArtwork(image: thumb)
            info[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    /// 更新播放信息
    private func updatePlayingInfo() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else {
            return
        }
        let player = VideoPlayer.shared
        info[MPMediaItemPropertyPlaybackDuration] = player.totalTime() ?? 0
        info[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: player.currentRate())
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = NSNumber(value: 1.0)
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: player.currentTime() ?? 0)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    /// 清理播放信息
    private func clearPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func playing() {
        updatePlayingInfo()
    }
    
    func loadingBegin() {
        updatePlayingInfo()
    }
    
    func loadingEnd() {
        updatePlayingInfo()
    }
    
    func paused() {
        updatePlayingInfo()
    }
    
    func finish() {
        updatePlayingInfo()
    }
    
    func updated(totalTime: Float) {
        updatePlayingInfo()
    }
    
    func seekFinish() {
        updatePlayingInfo()
    }
}
