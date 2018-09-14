import Foundation

protocol VideoPlayerDelagete: AnyObject {
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
    func updated(bufferProgress: Double)
    /// 更新总时间 (秒)
    func updated(totalTime: TimeInterval)
    /// 更新当前时间 (秒)
    func updated(currentTime: TimeInterval)
    /// 跳转完成
    func seekFinish()
}

extension VideoPlayerDelagete {
    
    func playing() { }
    func loadingBegin() { }
    func loadingEnd() { }
    func paused() { }
    func stopped() { }
    func finish() { }
    func error() { }
    
    func updated(bufferProgress: Double) { }
    func updated(totalTime: TimeInterval) { }
    func updated(currentTime: TimeInterval) { }
    func seekFinish() { }
}
