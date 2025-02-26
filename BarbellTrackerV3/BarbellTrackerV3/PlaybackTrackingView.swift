//
//  PlaybackTrackingView.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 2/23/25.
//

import SwiftUI
import AVKit
import Photos

/// A view that plays the video and overlays the precomputed tracking results.
struct PlaybackTrackingView: View {
    let asset: PHAsset
    @StateObject private var viewModel = OfflineTrackingViewModel()
    @State private var currentTrackingCenter: CGPoint? = nil
    
    // Timer to check the player's current time.
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            ZStack {
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fit)
                        .onAppear {
                            // Optionally, start playback.
                            player.play()
                        }
                } else {
                    Color.black
                }
                
                // Overlay: Draw tracking info.
                TrackingOverlayView(trackedCenter: currentTrackingCenter)
            }
            .navigationTitle("Playback with Tracking")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Process Video") {
                        viewModel.processVideo()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadVideo(from: asset)
        }
        .onReceive(timer) { _ in
            updateTrackingCenter()
        }
    }
    
    /// Update the overlay based on the player's current time by finding the latest tracking result.
    private func updateTrackingCenter() {
        guard let player = viewModel.player else { return }
        let currentTime = player.currentTime()
        // Find the latest tracking result with time less than or equal to current time.
        if let latest = viewModel.trackingResults.last(where: { $0.time <= currentTime }) {
            currentTrackingCenter = latest.center
        }
    }
}

#Preview {
    PlaybackTrackingView(asset: PHAsset())
}

