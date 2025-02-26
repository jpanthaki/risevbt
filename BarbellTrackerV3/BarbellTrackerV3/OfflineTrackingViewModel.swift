//
//  OfflineTrackingViewModel.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 2/23/25.
//

import SwiftUI
import AVFoundation
import Photos
import Vision

/// The view model that performs offline tracking on a video.
class OfflineTrackingViewModel: ObservableObject {
    @Published var trackingResults: [TrackingResult] = []
    @Published var videoAsset: AVAsset?
    @Published var player: AVPlayer?
    
    var visionProcessor: VisionTrackerProcessor?
    private var processingQueue = DispatchQueue(label: "processingQueue", qos: .userInitiated)
    
    /// Loads the video asset from a PHAsset.
    func loadVideo(from asset: PHAsset) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
            guard let self = self, let avAsset = avAsset else {
                print("Failed to load AVAsset from PHAsset")
                return
            }
            DispatchQueue.main.async {
                self.videoAsset = avAsset
                self.player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                // Set up the VisionTrackerProcessor (from Apple's provided core files).
                self.visionProcessor = VisionTrackerProcessor(videoAsset: avAsset)
                self.visionProcessor?.delegate = self
            }
        }
    }
    
    /// Processes the video offline to extract tracking results.
    func processVideo() {
        guard let _ = videoAsset, let processor = visionProcessor else {
            print("Missing video asset or vision processor")
            return
        }
        // Clear any previous tracking results.
        trackingResults = []
        processingQueue.async {
            do {
                // This method should process all frames.
                try processor.performTracking(type: .object)
            } catch {
                print("Error during offline tracking: \(error)")
            }
            DispatchQueue.main.async {
                print("Offline tracking complete. \(self.trackingResults.count) results collected.")
            }
        }
    }
}

extension OfflineTrackingViewModel: VisionTrackerProcessorDelegate {
    func displayFrame(_ frame: CVPixelBuffer?, withAffineTransform transform: CGAffineTransform, rects: [TrackedPolyRect]?) {
        // In offline processing, we capture tracking results instead of updating UI live.
        // Assume we are tracking one object.
        if let rects = rects, let firstRect = rects.first {
            let box = firstRect.boundingBox
            // Assume the bounding box is normalized (0...1). Its center:
            let center = CGPoint(x: box.midX, y: box.midY)
            
            // For timestamp, try to use the player's currentTime if available.
            let currentTime = player?.currentTime() ?? CMTime.zero
            DispatchQueue.main.async {
                self.trackingResults.append(TrackingResult(time: currentTime, center: center))
                print("Collected tracking result at time: \(CMTimeGetSeconds(currentTime)), center: \(center)")
            }
        }
    }
    
    func displayFrameCounter(_ frame: Int) {
        print("Processing frame: \(frame)")
    }
    
    func didFinifshTracking() {
        DispatchQueue.main.async {
            print("Offline tracking finished.")
        }
    }
}



