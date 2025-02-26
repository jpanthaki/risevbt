//
//  TrackingImageView.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 2/22/25.
//

import SwiftUI

struct TrackingImageView: View {
    var image: UIImage?
    var rubberbandingRect: CGRect?
    var trackingPath: [CGPoint]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    Color.black
                }

                if let rect = rubberbandingRect, rect != .zero {
                    Path { path in
                        path.addRect(rect)
                    }
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [4,2]))
                }
                
                Path { path in
                    guard let first = trackingPath.first else { return }
                    path.move(to:first)
                    for point in trackingPath.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.green, lineWidth: 3)
            }
        }
    }
}

#Preview {
    TrackingImageView(image: UIImage(systemName: "photo"),
                      rubberbandingRect: CGRect(x: 50, y: 50, width: 100, height: 80),
                      trackingPath: [CGPoint(x: 60, y: 60), CGPoint(x: 120, y: 120), CGPoint(x: 180, y: 100)]
    )
}
