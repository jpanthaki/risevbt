//
//  VideoPlayerView.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 2/22/25.
//

import SwiftUI
import AVKit
import Photos

struct VideoPlayerView: View {
    
    let asset: PHAsset
    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    
    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fit)
                    .onDisappear() {
                        player.pause()
                        removeObserver(from: player)
                    }
            } else {
                Text("Loading video...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.2))
            }
        }
        .navigationTitle("Video Playback")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button("Clear") {
                        //clear logic
                        clearVideo()
                    }
                    Button(action: {
                        togglePlayPause()
                    }) {
                        Text(isPlaying ? "Pause": "Play")
                    }
                }
            }
        }
        .onAppear {
            loadPlayer()
        }
    }
    
    private func loadPlayer() {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
            if let playerItem = playerItem {
                DispatchQueue.main.async {
                    self.player = AVPlayer(playerItem: playerItem)
                    addObserver(to: self.player!)
                }
            }
        }
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        
        isPlaying.toggle()
    }
    
    private func clearVideo() {
        guard let player = player else { return }
        
        player.seek(to: .zero) { _ in
            player.pause()
            self.isPlaying = false
        }
    }
    
    private func addObserver(to player: AVPlayer) {
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main) { _ in
                
                player.seek(to: .zero) { _ in
                    player.pause()
                    self.isPlaying = false
                }
            }
    }
    
    private func removeObserver(from player: AVPlayer) {
        NotificationCenter.default.removeObserver(self,
                                                  name: .AVPlayerItemDidPlayToEndTime,
                                                  object: player.currentItem)
    }
}
