//
//  TrackingOverlayView.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 2/23/25.
//

import SwiftUI

/// A view that draws tracking overlays on a transparent background.
struct TrackingOverlayView: View {
    /// The tracked center, assumed to be normalized (0...1)
    var trackedCenter: CGPoint?
    
    var body: some View {
        GeometryReader { geometry in
            if let center = trackedCenter {
                // Convert normalized coordinates to view coordinates.
                let x = center.x * geometry.size.width
                let y = (1 - center.y) * geometry.size.height // Invert y if needed.
                Circle()
                    .fill(Color.green)
                    .frame(width: 20, height: 20)
                    .position(x: x, y: y)
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    // Preview with a dummy normalized center.
    TrackingOverlayView(trackedCenter: CGPoint(x: 0.5, y: 0.5))
}

