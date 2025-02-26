//
//  TrackingView.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 2/22/25.
//

import SwiftUI
import Photos

struct TrackingView: View {
    
    let asset: PHAsset
    @StateObject private var viewModel = TrackingViewModel()
    
    
    var body: some View {
        NavigationView {
            TrackingImageView(
                image: viewModel.currentFrame,
                rubberbandingRect: viewModel.rubberbandingRect,
                trackingPath: viewModel.trackedRects.flatMap { rect -> [CGPoint] in
                    let box = rect.boundingBox
                    return [CGPoint(x: box.midX, y: box.midY)]
                }
            )
            .coordinateSpace(name: "trackingArea")
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .named("trackingArea"))
                    .onChanged { value in
                        print("Dragging at: \(value.location)")
                        viewModel.updateRubberbanding(with: value.location)
                    }
                    .onEnded { value in
                        print("Finished dragging at: \(value.location)")
                        viewModel.finishRubberbanding(with: value.location)
                    }
            )
            .navigationTitle("Tracking")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        viewModel.clearTracking()
                    }
                    Button(action: {
                        viewModel.togglePlayPause()
                    }) {
                        Text(viewModel.isPlaying ? "Pause" : "Play")
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadVideo(from: asset)
        }
    }
}

#Preview {
    TrackingView(asset: PHAsset())
}
