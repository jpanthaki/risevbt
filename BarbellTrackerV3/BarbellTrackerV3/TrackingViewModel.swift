//
//  TrackingViewModel.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 2/22/25.
//

import SwiftUI
import AVFoundation
import Photos
import Vision

class TrackingViewModel: ObservableObject {
    @Published var currentFrame: UIImage? = UIImage(systemName: "photo")
    @Published var trackedRects: [TrackedPolyRect] = []
    @Published var rubberbandingRect: CGRect = .zero
    @Published var trackingPath: [CGPoint] = []
    @Published var isPlaying: Bool = false
    
    private var videoAsset: AVAsset?
    private var player: AVPlayer?
    var visionProcessor: VisionTrackerProcessor?
    private var trackingQueue = DispatchQueue(label: "trackingQueue", qos: .userInitiated)
    
    
    private var startPoint: CGPoint? = nil
    
    func loadVideo(from asset: PHAsset) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            if let avAsset = avAsset {
                print("successfully loaded video: \(avAsset)")
                DispatchQueue.main.async {
                    self.videoAsset = avAsset
                    self.player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                    self.visionProcessor = VisionTrackerProcessor(videoAsset: avAsset)
                    self.visionProcessor?.delegate = self
                    self.startDisplayFirstFrame()
                }
            } else {
                print("failed to load AVAssest from PHAsset")
            }
        }
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func clearTracking() {
        trackedRects.removeAll()
        trackingPath.removeAll()
        rubberbandingRect = .zero
        startPoint = nil
        visionProcessor?.cancelTracking()
        player?.seek(to: .zero)
        isPlaying = false
        startDisplayFirstFrame()
    }
    
    func updateRubberbanding(with location: CGPoint) {
        if startPoint == nil {
            startPoint = location
            rubberbandingRect = CGRect(origin: location, size: .zero)
        } else if let start = startPoint {
            rubberbandingRect = CGRect(
                x: min(start.x, location.x),
                y: min(start.y, location.y),
                width: abs(start.x - location.x),
                height: abs(start.y - location.y)
            )
        }
    }
    
    func finishRubberbanding(with location: CGPoint) {
        updateRubberbanding(with: location)
        
        guard rubberbandingRect.width > 0, rubberbandingRect.height > 0 else {
            startPoint = nil
            rubberbandingRect = .zero
            return
        }
        
        startTracking(with: rubberbandingRect)
        startPoint = nil
        rubberbandingRect = .zero
    }
    
    func startDisplayFirstFrame() {
        trackingQueue.async {
            do {
                try self.visionProcessor?.readAndDisplayFirstFrame(performRectanglesDetection: false)
            } catch {
                print("Error reading first frame: \(error)")
            }
        }
    }
    
    private func startTracking(with box: CGRect) {
        guard let visionProcessor = visionProcessor else { return }
        
        let trackedRect = TrackedPolyRect(cgRect: box, color: .red, style: .solid)
        visionProcessor.objectsToTrack = [trackedRect]
        trackingQueue.async {
            do {
                try visionProcessor.performTracking(type: .object)
            } catch {
                print("Error during tracking: \(error)")
            }
        }
    }
}

extension TrackingViewModel: VisionTrackerProcessorDelegate {
    func displayFrame(_ frame: CVPixelBuffer?, withAffineTransform transform: CGAffineTransform, rects: [TrackedPolyRect]?) {
        if let frame = frame {
            let ciImage = CIImage(cvPixelBuffer: frame).transformed(by: transform)
            let context = CIContext(options: nil)
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                print("Received frame image, size: \(uiImage.size)")
                DispatchQueue.main.async {
                    self.currentFrame = uiImage
                }
            } else {
                print("Failed to create CGIMage from CIImage")
            }
            
            
//            let uiImage = UIImage(ciImage: ciImage)
//            print("Received frame image. Size: \(uiImage.size)")
//            DispatchQueue.main.async {
//                self.currentFrame = uiImage
//            }
        } else {
            print("no frame received")
        }
        
        DispatchQueue.main.async {
            self.trackedRects = rects ?? []
            if let firstRect = rects?.first {
                let box = firstRect.boundingBox
                let center = CGPoint(x: box.midX, y: box.midY)
                self.trackingPath.append(center)
            }
        }
    }
    
    func displayFrameCounter(_ frame: Int) {
        print("Frame: \(frame)")
    }
    
    func didFinifshTracking() {
        DispatchQueue.main.async {
            print("Tracking Finished.")
        }
    }
    
    
}
