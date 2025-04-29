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

func processVideo(inputURL: URL, outputURL: URL) async -> URL? {
    
    let asset = AVURLAsset(url: inputURL)
    
    let processor: TrackerProcessor
    do {
        processor = try TrackerProcessor(videoAsset: asset)
    } catch {
        print("failed to load model or asset", error)
        return nil
    }
    
    let boxes: [CGRect]
    do {
        boxes = try processor.processVideo()
    } catch {
        print("Tracking failed: \(error)")
        return nil
    }
    print("Tracked \(boxes.count) frames")
    
    let overlayProcessor = VideoOverlayProcessor()
    
    let lineHandler = VideoOverlayProcessor.makePathHandler(boxes: boxes, color: CGColor(red: 0, green: 1, blue: 0, alpha: 1), lineWidth: 4)
    
    do {
        let _ = try await overlayProcessor.process(
            inputURL: inputURL,
            outputURL: outputURL,
            overlayHandler: lineHandler,
        )
        print("Wrote overlaid video to outputURL")
    } catch {
        print("Error processing video")
        return nil
    }
    
    return outputURL
}
