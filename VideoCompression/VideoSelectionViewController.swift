//
//  ViewController.swift
//  VideoCompression
//
//  Created by Jordan Doczy on 1/13/17.
//  Copyright © 2017 Jordan Doczy. All rights reserved.
//

import AVKit
import AVFoundation
import MobileCoreServices
import Photos
import UIKit

class VideoSelectionViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    enum State {
        case initialized
        case loading
        case complete(message: String)
        case failure(message: String)
    }
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var playCompressedVideoButton: UIButton!
    @IBOutlet weak var videoInformationLabel: UILabel!
    @IBOutlet weak var videoSelectionButton: UIButton!
    
    private var outputURL: URL?

    private var state:State = .initialized {
        didSet{
            switch state {
            case .initialized:
                activityIndicator.isHidden = true
                activityIndicator.stopAnimating()
                playCompressedVideoButton.isHidden = true
                videoInformationLabel.text = ""
                videoSelectionButton.isHidden = false
            case .loading:
                activityIndicator.isHidden = false
                activityIndicator.startAnimating()
                playCompressedVideoButton.isHidden = true
                videoInformationLabel.text = ""
                videoSelectionButton.isHidden = true
            case .complete(let message):
                activityIndicator.isHidden = true
                activityIndicator.stopAnimating()
                playCompressedVideoButton.isHidden = false
                videoSelectionButton.isHidden = false
                videoInformationLabel.text = message
            case .failure(let message):
                activityIndicator.isHidden = true
                activityIndicator.stopAnimating()
                playCompressedVideoButton.isHidden = true
                videoSelectionButton.isHidden = false
                videoInformationLabel.text = message
            }
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        state = .initialized
    }

    @IBAction func onVideoSelectionClicked(_ sender: UIButton) {
        let controller = UIImagePickerController()
        controller.mediaTypes = [kUTTypeMovie as String]
        controller.delegate = self
        show(controller, sender: self)
        
        state = .loading
    }
    
    @IBAction func playCompressedVideo(_ sender: UIButton) {
        guard let outputURL = outputURL else {
            return
        }
        
        let player = AVPlayer(url: outputURL)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        
        present(playerViewController, animated: true) {
            playerViewController.player?.play()
        }
    }
    
//    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
//        picker.dismiss(animated: true) { [weak self] in
//            if let url = info[UIImagePickerControllerMediaURL] as? URL {
////                self?.exportURLFromAVAssetExportSession(url: url)
//                self?.exportURLFromSDAVAssetExportSession(url: url)
//            }
//        }
//    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true) { [weak self] in
            if let url = info[UIImagePickerControllerReferenceURL] as? URL {
                let result = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil)
                guard let asset = result.firstObject else {
                    return
                }
                
                let options = PHVideoRequestOptions()
                options.version = PHVideoRequestOptionsVersion.original
                PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] asset, audioMix, info in
                    if let asset = asset as? AVURLAsset {
                        let videoPath = NSTemporaryDirectory() + "\(Date().timeIntervalSinceNow)_tmpMovie.MOV"
                        let videoURL = URL(fileURLWithPath: videoPath)
                        
                        do {
                            let videoData = try Data(contentsOf: asset.url)
                            _ = try videoData.write(to: videoURL)
                        } catch {
                            DispatchQueue.main.async {
                                self?.state = .failure(message: "could not write video data")
                            }
                        }
                        
//                        self?.exportURLFromAVAssetExportSession(url: videoURL)
                        self?.exportURLFromSDAVAssetExportSession(url: videoURL)
                    }
                }
            }
        }
    }
    
    func exportURLFromSDAVAssetExportSession(url: URL) {
        let asset = AVAsset(url: url)
        
        let width = 320 //720
        let height = 568 //1280
        let videoBitrate = 800000 //6400000
        let audioBitrate = 64000 //128000
        let audioSampleRate = 44100
        
        let exportSession = SDAVAssetExportSession(asset: asset)!
        exportSession.outputURL = url.deletingPathExtension().appendingPathExtension("mp4")
        exportSession.outputFileType = AVFileTypeMPEG4
        exportSession.timeRange = CMTimeRange(start: kCMTimeZero, duration: asset.duration)
        exportSession.shouldOptimizeForNetworkUse = true
        
        exportSession.videoSettings = [AVVideoCodecKey: AVVideoCodecH264,
                                       AVVideoWidthKey: width,
                                       AVVideoHeightKey: height,
                                       AVVideoCompressionPropertiesKey:
                                        [AVVideoAverageBitRateKey: videoBitrate]]
        
        exportSession.audioSettings = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                       AVNumberOfChannelsKey: 2,
                                       AVSampleRateKey: audioSampleRate,
                                       AVEncoderBitRateKey: audioBitrate]
        
        exportSession.exportAsynchronously { [weak self] in
            DispatchQueue.main.async {
                self?.exportComplete(status: exportSession.status, originalURL: url, outputURL: exportSession.outputURL!)
            }
        }
    }
    
    func exportURLFromAVAssetExportSession(url: URL) {
        
        // Preset Options:
        // AVAssetExportPresetLowQuality / AVAssetExportPresetMediumQuality / AVAssetExportPresetHighestQuality
        // AVAssetExportPreset640x480 / AVAssetExportPreset960x540 / AVAssetExportPreset1280x720 / AVAssetExportPreset1920x1080 / AVAssetExportPreset3840x2160
        
        let presetName = AVAssetExportPresetMediumQuality
        let asset = AVAsset(url: url)
        let exportSession = AVAssetExportSession(asset: asset, presetName: presetName)!
        exportSession.outputURL = url.deletingPathExtension().appendingPathExtension("mp4")
        exportSession.outputFileType = AVFileTypeMPEG4
        exportSession.timeRange = CMTimeRange(start: kCMTimeZero, duration: asset.duration)
        exportSession.shouldOptimizeForNetworkUse = true
        
        exportSession.exportAsynchronously { [weak self] in
            DispatchQueue.main.async {
                self?.exportComplete(status: exportSession.status, originalURL: url, outputURL: exportSession.outputURL!)
            }
        }
    }
    
    func exportComplete(status: AVAssetExportSessionStatus, originalURL: URL, outputURL: URL) {
        switch status {
        case .completed:
            do {
                let originalData = try Data(contentsOf: originalURL)
                let originalAsset = AVAsset(url: originalURL)
                let originalVideoTrack = originalAsset.tracks(withMediaType: AVMediaTypeVideo).first!

                let data = try Data(contentsOf: outputURL)
                let asset = AVAsset(url: outputURL)
                let videoTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first!
                
                self.outputURL = outputURL
                state = .complete(message: "Original mbs: \(originalData.countInMegabytes(places: 3))\rOriginal wxh: \(Int(originalVideoTrack.naturalSize.width))x\(Int(originalVideoTrack.naturalSize.height))\rOriginal bitrate: \(Int(originalVideoTrack.estimatedDataRate))\rOriginal frame rate: \(originalVideoTrack.nominalFrameRate)\r\rCompressed mbs: \(data.countInMegabytes(places: 3))\rCompressed wxh: \(Int(videoTrack.naturalSize.width))x\(Int(videoTrack.naturalSize.height))\rCompress bitrate: \(Int(videoTrack.estimatedDataRate))\rCompressed frame rate: \(videoTrack.nominalFrameRate)")
                
            } catch {
                state = .failure(message: "error reading data")
            }
        case .cancelled:
            state = .complete(message: "export cancelled")
        default:
            state = .failure(message: "failed")
        }
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        state = .complete(message: "export cancelled")
    }
}

extension Data {
    func countInMegabytes(places: Int) -> Double {
        return (Double(count)/1024.0/1024.0).roundTo(places: places)
    }
}

extension Double {
    func roundTo(places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
