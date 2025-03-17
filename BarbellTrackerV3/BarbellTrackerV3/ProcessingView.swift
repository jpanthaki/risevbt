//
//  ProcessingView.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 3/16/25.
//

import SwiftUI
import AVFoundation
import Photos

struct ProcessingView: View {
    var phAsset: PHAsset
    var videoAsset: AVAsset
    var initialRect: CGRect
    
//    @State private var progress: Double = 0.0
    @State private var rectangles: [CGRect]? = nil
    @State private var isDone: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack (spacing: 20) {
                Text("Processing Video...")
                    .font(.headline)
                //            ProgressView(value: progress)
                //                .progressViewStyle(LinearProgressViewStyle())
                //                .padding(.horizontal)
                //            Text("\(Int(progress * 100))")
            }
        }
        .onAppear {
            processVideo()
        }
        .navigationDestination(isPresented: $isDone) {
            if let boxes = rectangles {
                TrackingOverlayView(asset: phAsset, rectangles: boxes)
            } else {
                Text("Object Tracking Failed")
            }
        }
    }
    
    private func processVideo() {
        let tracker = TrackerProcessor(videoAsset: videoAsset, initialBoundingBox: initialRect)
        
        do {
            let result = try tracker.processVideo()
            DispatchQueue.main.async {
                rectangles = result
                isDone = true
            }
        } catch {
            print("Error Processing Video: \(error)")
        }
    }
}

struct RectanglesAnimationView: View {
    // Array of normalized CGRects produced by the TrackerProcessor.
    let rectangles: [CGRect]
    
    // The current frame index (i.e. the rectangle to display).
    @State private var currentIndex: Int = 0
    
    // Timer that ticks every 0.2 seconds to update the displayed rectangle.
    let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            
            ZStack {
                // White background.
                Color.white.ignoresSafeArea()
                
                // Check that we have at least one rectangle.
                if !rectangles.isEmpty {
                    // Convert the normalized rectangle to actual coordinates.
                    let normRect = rectangles[currentIndex]
                    let actualRect = denormalizeRect(normRect, in: containerSize)
                    
                    // Draw the rectangle.
                    Rectangle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: actualRect.width, height: actualRect.height)
                        .position(x: actualRect.midX, y: actualRect.midY)
                }
            }
            .onReceive(timer) { _ in
                // Move to the next rectangle in the array.
                if !rectangles.isEmpty {
                    currentIndex = (currentIndex + 1) % rectangles.count
                }
            }
        }
        .navigationTitle("Animation")
    }
    
    private func denormalizeRect(_ normalizedRect: CGRect, in viewSize: CGSize) -> CGRect {
        let width = normalizedRect.width * viewSize.width
        let height = normalizedRect.height * viewSize.height
        let x = normalizedRect.origin.x * viewSize.width
        // Convert from Vision's lower-left origin to the top-left origin.
        let y = (1.0 - normalizedRect.origin.y - normalizedRect.height) * viewSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
