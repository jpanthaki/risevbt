//
//  TrackingOverlayView.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 3/16/25.
//

import SwiftUI
import AVKit
import Photos

struct TrackingOverlayView: View {
    let asset: PHAsset
    let rectangles: [CGRect]
    
    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    @State private var isProcessingDone: Bool = false
    @State private var isVideoLoaded: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // 1) The video
                if let player = player {
                    VideoPlayer(player: player)
                        .onAppear {
                            // Start playback if you wish
                            player.play()
                        }
                        .scaledToFit()
                        .frame(width: geometry.size.width,
                               height: geometry.size.height)
                    
                } else {
                    Color.black // or ProgressView while loading
                }
                
                // 2) The overlay rectangles
//                ForEach(rectangles, id: \.self) { normalizedRect in
//                    let denormalized = denormalizeRect(normalizedRect, in: geometry.size)
//                    
//                    Rectangle()
//                        .stroke(Color.red, lineWidth: 2)
//                        .frame(width: denormalized.width,
//                               height: denormalized.height)
//                        .position(x: denormalized.midX,
//                                  y: denormalized.midY)
//                }
                
                Path { path in
                    // Convert each bounding box to a denormalized midpoint
                    let points = rectangles.map { box -> CGPoint in
                        let denorm = denormalizeRect(box, in: geometry.size)
                        return CGPoint(x: denorm.midX,
                                       y: denorm.midY)
                    }
                    
                    // Connect them in a single continuous path
                    if let first = points.first {
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(Color.red, lineWidth: 2)
            }
        }
        .onAppear {
            // Example: load your AVPlayer here
            // Then fetch bounding boxes from TrackerProcessor and set self.rectangles
            loadPlayer()
        }
    }
    
    private func denormalizeRect(_ normalizedRect: CGRect, in viewSize: CGSize) -> CGRect {
        let width = normalizedRect.width * viewSize.width
        let height = normalizedRect.height * viewSize.height
        let x = normalizedRect.origin.x * viewSize.width
        // Convert from Vision's lower-left origin to the top-left origin.
        let y = (1.0 - normalizedRect.origin.y - normalizedRect.height) * viewSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func loadPlayer() {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
            if let playerItem = playerItem {
                DispatchQueue.main.async {
                    self.player = AVPlayer(playerItem: playerItem)
//                    addObserver(to: self.player!)
                }
            }
        }
    }
    
    
}
