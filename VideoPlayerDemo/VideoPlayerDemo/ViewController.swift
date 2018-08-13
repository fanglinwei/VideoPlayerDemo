//
//  ViewController.swift
//  VideoPlayerDemo
//
//  Created by 李响 on 2018/5/31.
//  Copyright © 2018年 李响. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var playerView: VideoPlayerView!
    
    private lazy var controlView = VideoPlayerControlView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.layoutIfNeeded()
        view.addSubview(controlView)
        playerView.set(controlView: controlView)
        
        let url = URL(string: "https://devstreaming-cdn.apple.com/videos/tutorials/20170912/801xy9x7h32rn/designing_for_iphone_x/hls_vod_mvp.m3u8")!
        playerView.play(url: url)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        controlView.frame = playerView.frame
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

extension ViewController {
    
    
    
}
