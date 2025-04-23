//
//  ProcessVideo.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/23/25.
//

import Foundation
import AVFoundation
import Vision
import CoreGraphics

//func processVideo(url: URL) -> URL? {
//    
//    let asset = AVURLAsset(url: url)
//    
//    let processor: TrackerProcessor
//    do {
//        processor = try TrackerProcessor(videoAsset: asset)
//    } catch {
//        print("failed to load model or asset", error)
//        return nil
//    }
//    
//    let boxes: [CGRect]
//    do {
//        boxes = try processor.processVideo()
//    } catch {
//        print("Tracking failed: \(error)")
//        return nil
//    }
//    print("Tracked \(boxes.count) frames")
//    
//    let overlayProcessor = VideoOverlayProcessor()
//    
//    let lineHandler = VideoOverlayProcessor.makePathHandler(boxes: boxes, color: CGColor(red: 0, green: 1, blue: 0, alpha: 1))
//    
//    do {
//        let finalURL = try await overlayProcessor.process(
//            inputURL: url,
//            outputURL: 
//        )
//    }
//    
//    
//    
//}
