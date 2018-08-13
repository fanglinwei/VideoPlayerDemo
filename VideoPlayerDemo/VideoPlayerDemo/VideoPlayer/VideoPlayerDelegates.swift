//
//  VideoPlayerDelegates.swift
//
//  Created by 李响 on 2018/5/31.
//  Copyright © 2018年 李响. All rights reserved.
//

import Foundation

protocol VideoPlayerDelegates: NSObjectProtocol {
    associatedtype T
    
    var delegates: [DelegateBridge<AnyObject>] { get set }
}

extension VideoPlayerDelegates {
    
    func add(delegate: T) {
        guard !delegates.contains(where: { $0.object === delegate as AnyObject }) else {
            return
        }
        delegates.append(DelegateBridge(delegate as AnyObject))
    }
    
    func remove(delegate: T) {
        guard let index = delegates.index(where: { $0.object === delegate as AnyObject }) else {
            return
        }
        delegates.remove(at: index)
    }
    
    func delegate(_ operat: @escaping (T) -> Void) {
        delegates = delegates.filter({ $0.object != nil })
        for delegate in delegates {
            guard let object = delegate.object else { continue }
            guard let o = object as? T else { continue }
            operat(o)
        }
    }
}

class DelegateBridge<T: AnyObject> {
    weak var object: T?
    init(_ object: T?) {
        self.object = object
    }
}
