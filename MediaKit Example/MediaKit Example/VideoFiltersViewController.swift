//
//  VideoFiltersViewController.swift
//  MediaKit Example
//
//  Created by Adrian Mateoaea on 18/02/2017.
//  Copyright © 2017 Flurgle. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation

public class MKFilteredVideoPlayer: UIView {
    
    public var asset: AVAsset? {
        didSet {
            setup()
        }
    }
    
    public var filter: CIFilter?
    public var player: AVPlayer?
    
    public var loop: Bool = false {
        didSet {
            if loop {
                player?.actionAtItemEnd = .none
                NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
            } else {
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
    
    private var playerLayer: AVPlayerLayer?
    
    public func play(loop: Bool) {
        self.loop = loop
        player?.play()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setup() {
        layer.sublayers?.forEach {
            if $0 is AVPlayerLayer {
                $0.removeFromSuperlayer()
            }
        }
        
        guard let asset = asset else {
            return
        }
        
        let item = AVPlayerItem(asset: asset)
        item.videoComposition = AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: processFrame)
        
        let player = AVPlayer(playerItem: item)
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = bounds
        layer.addSublayer(playerLayer)
        
        self.player = player
        self.playerLayer = playerLayer
    }
    
    private func processFrame(_ request: AVAsynchronousCIImageFilteringRequest) {
        guard let filter = filter else {
            request.finish(with: request.sourceImage, context: nil)
            return
        }
        
        let source = request.sourceImage.clampingToExtent()
        filter.setValue(source, forKey: kCIInputImageKey)
        let output = filter.outputImage!.cropping(to: request.sourceImage.extent)
        request.finish(with: output, context: nil)
    }
    
    @objc private func playerItemDidPlayToEndTime() {
        player?.seek(to: CMTime.init(seconds: 0, preferredTimescale: 1000))
        player?.play()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}

class VideoFiltersViewController: UIViewController {
    
    @IBOutlet weak var videoPlayer: MKFilteredVideoPlayer!
    @IBOutlet weak var collectionView: UICollectionView!
    
    fileprivate let filters: [MKFilter] = [
        MKFilter(name: "None", filterName: nil),
        MKFilter(name: "Chrome", filterName: "CIPhotoEffectChrome"),
        MKFilter(name: "Fade", filterName: "CIPhotoEffectFade"),
        MKFilter(name: "Instant", filterName: "CIPhotoEffectInstant"),
        MKFilter(name: "Mono", filterName: "CIPhotoEffectMono"),
        MKFilter(name: "Process", filterName: "CIPhotoEffectProcess"),
        MKFilter(name: "Sepia", filterName: "CISepiaTone"),
        MKFilter(name: "Vignette", filterName: "CIVignette"),
        MKFilter(name: "Photo Transfer", filterName: "CIPhotoEffectTransfer"),
        MKFilter(name: "Tonal", filterName: "CIPhotoEffectTonal"),
        MKFilter(name: "Invert", filterName: "CIColorInvert"),
        MKFilter(name: "Vibrance", filterName: "CIVibrance"),
        MKFilter(name: "Kaleidoscope", filterName: "CIKaleidoscope"),
        MKFilter(name: "Tile", filterName: "CIOpTile"),
    ]
    
    fileprivate var thumbnails: [UIImage?] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let url = Bundle.main.url(forResource: "Video", withExtension: "mp4") {
            let asset = AVAsset(url: url)
            
            videoPlayer.asset = asset
            videoPlayer.player?.isMuted = true
            videoPlayer.play(loop: true)
            
            let generator = AVAssetImageGenerator(asset: asset)
            let time = NSValue(time: CMTime(seconds: 0.0, preferredTimescale: 1000))
            generator.generateCGImagesAsynchronously(forTimes: [time], completionHandler: { (_, cgImage, _, _, _) in
                if let cgImage = cgImage {
                    self.generateThumbnails(UIImage(cgImage: cgImage))
                }
            })
        }
    }
    
    private func generateThumbnails(_ image: UIImage) {
        thumbnails = Array(repeating: nil, count: filters.count)
        
        DispatchQueue.global(qos: .default).async {
            guard let resizedImage = image.resize(aspectFill: CGSize(width: 100, height: 100)) else {
                return
            }
            guard let ciImage = CIImage(image: resizedImage) else {
                return
            }
            
            self.filters.enumerated().forEach { (index, element) in
                var finalImage = resizedImage
                
                if let filter = element.filter {
                    filter.setValue(ciImage, forKey: kCIInputImageKey)
                    if let outputImage = filter.outputImage {
                        let rect = outputImage.extent
                        if let cgImage = CIContext().createCGImage(outputImage, from: rect) {
                            finalImage = UIImage(cgImage: cgImage)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.thumbnails[index] = finalImage
                    if let cell = self.collectionView.cellForItem(at: IndexPath(row: index, section: 0)) as? FilterCollectionViewCell {
                        cell.imageView.image = finalImage
                    }
                }
            }
        }
    }
}

extension VideoFiltersViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return thumbnails.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterCollectionViewCell",
                                                      for: indexPath) as! FilterCollectionViewCell
        
        cell.imageView.image = thumbnails[indexPath.row]
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let filter = filters[indexPath.row].filter
        videoPlayer.filter = filter
    }
}
