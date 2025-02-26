//
//  TrackingResult.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 2/23/25.
//

import AVFoundation
import CoreGraphics

struct TrackingResult: Identifiable {
    let id = UUID()
    let time: CMTime
    let center: CGPoint
}
