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
            case .complete(let message), .failure(let message):
                activityIndicator.isHidden = true
                activityIndicator.stopAnimating()
                playCompressedVideoButton.isHidden = false
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
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true) { [weak self] in
            if let url = info[UIImagePickerControllerMediaURL] as? URL {
                self?.exportURLFromAVAssetExportSession(url: url)
                //self?.exportURLFromSDAVAssetExportSession(url: url)
            }
        }
    }
    
    func exportURLFromSDAVAssetExportSession(url: URL) {
        let asset = AVAsset(url: url)
        
        let width = 720
        let height = 1280
        let videoBitrate = 6400000
        let audioBitrate = 128000
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
                                       AVNumberOfChannelsKey: 1,
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
        
        let presetName = AVAssetExportPresetHighestQuality
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
                let originalDimensions = VideoSelectionViewController.getVideoSize(asset: AVAsset(url: originalURL))

                let data = try Data(contentsOf: outputURL)
                let dimensions = VideoSelectionViewController.getVideoSize(asset: AVAsset(url: outputURL))
                
                self.outputURL = outputURL
                state = .complete(message: "Original video bytes: \(originalData.count)\rOriginal video wxh: \(Int(originalDimensions.width))x\(Int(originalDimensions.height))\r\rCompressed video bytes: \(data.count)\rCompressed video wxh: \(Int(dimensions.width))x\(Int(dimensions.height))")
                
            } catch {
                state = .failure(message: "error reading data")
            }
        case .cancelled:
            state = .complete(message: "export cancelled")
        default:
            state = .failure(message: "failed")
        }
        
    }
    
    static func getVideoSize(asset: AVAsset) -> CGSize {
        let tracks = asset.tracks.filter { $0.mediaType == AVMediaTypeVideo }
        return tracks.first?.naturalSize ?? CGSize.zero
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        state = .complete(message: "export cancelled")
    }
}

