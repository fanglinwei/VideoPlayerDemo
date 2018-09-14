//
//  VideoPlayerUtils.swift
//  VideoPlayerDemo
//
//  Created by 李响 on 2018/6/1.
//  Copyright © 2018年 李响. All rights reserved.
//

import Foundation
import UIKit

enum VideoPlayerUtils {}

/// 延迟任务
extension VideoPlayerUtils {
    
    typealias DelayTask = (_ cancel : Bool) -> Void
    
    static func delay(time: TimeInterval, task: @escaping () -> Void) -> DelayTask? {
        
        func dispatch_later(block: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + time, execute: block)
        }
        
        var closure: (() -> Void)? = task
        var result: DelayTask?
        
        let delayedClosure: DelayTask = { cancel in
            defer {
                closure = nil
                result = nil
            }
            guard let internalClosure = closure, !cancel else { return }
            
            DispatchQueue.main.async(execute: internalClosure)
        }
        
        result = delayedClosure
        
        dispatch_later {
            guard let delayedClosure = result else { return }
            
            delayedClosure(false)
        }
        
        return result
    }
    
    static func cancel(task: DelayTask?) {
        task?(true)
    }
}
