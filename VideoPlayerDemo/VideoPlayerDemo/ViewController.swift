//
//  ViewController.swift
//  VideoPlayerDemo
//
//  Created by 李响 on 2018/5/31.
//  Copyright © 2018年 李响. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var plPlayerView: UIView!
    
    private lazy var controlView = VideoPlayerControlView()
    private lazy var coverView = VideoPlayerCoverView()
    private lazy var errorView = VideoPlayerErrorView()
    private lazy var finishView = VideoPlayerFinishView()
    
    private var pv: VideoPlayerView?
    private var provider: VideoPlayerProvider?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.layoutIfNeeded()
        view.addSubview(controlView)
        view.addSubview(coverView)
        view.addSubview(errorView)
        view.addSubview(finishView)
        
        let url = URL(string: "https://devstreaming-cdn.apple.com/videos/tutorials/20170912/801xy9x7h32rn/designing_for_iphone_x/hls_vod_mvp.m3u8")!
        
//        let url = URL(string: "https://p-events-delivery.akamaized.net/189kljhbasdcvjhasbdscvoahsbdcvaoshdbvaosdhbvasodhjbv/m3u8/hls_vod_mvp.m3u8")!
        
        coverView.imageView.image = #imageLiteral(resourceName: "video_cover")
        
        let player = VideoPlayer.instance(.av)
        let provider = VideoPlayerProvider(
            control: controlView,
            finish: finishView,
            error: errorView,
            cover: coverView
        ) { [weak self] in
            guard let this = self else { return }
            
            player.prepare(url: url)
            this.playerView.subviews.forEach({ $0.removeFromSuperview() })
            this.playerView.addSubview(player.view)
            player.view.frame = this.playerView.bounds
            this.pv = player.view
        }
        provider.set(player: player)
        self.provider = provider
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            player.stop()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        controlView.frame = playerView.frame
        coverView.frame = playerView.frame
        errorView.frame = playerView.frame
        finishView.frame = playerView.frame
        pv?.frame = playerView.bounds
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
