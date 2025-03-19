//
//  TrackerProcessor.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 3/13/25.
//

import AVFoundation
import Vision

enum TrackerProcessorError: Error {
    case readerInitializationFailed
    case firstFrameReadFailed
    case objectTrackingFailed
}

class TrackerProcessor {
    let videoAsset: AVAsset
    
    var initialObservation: VNDetectedObjectObservation
    var boundingBoxes: [CGRect] = []
    
    init(videoAsset: AVAsset, initialBoundingBox: CGRect) {
        self.videoAsset = videoAsset
        self.initialObservation = VNDetectedObjectObservation(boundingBox: initialBoundingBox)
    }
    
    func convertNormalizedRect(_ normalizedRect: CGRect, videoSize: CGSize) -> CGRect {
        let x = normalizedRect.minX * videoSize.width
        // Vision has origin at the bottom-left; SwiftUI usually has origin at top-left.
        let y = (1.0 - normalizedRect.maxY) * videoSize.height
        let width = normalizedRect.width * videoSize.width
        let height = normalizedRect.height * videoSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    func processVideo() throws -> [CGRect] {
        
        //set current observation to the initial observation
        //initialize the request handler VNSequenceRequestHandler
        //iterate through the videoreader until there's no frames left
        //inside of loop:
            //initialize tracking request on current observation VNTrackObjectRequest
            //set tracking level to accurate
            // try to perform tracking request using request handler on that frame with the videoreader's observation
            // try to set new observation based on the tracking request's results, with type VNDetectedObjectObservation
            // set the currentObservation to the newObservation
            //append the currentObservation's bounding box to the bounding boxes.
        
        guard let videoReader = VideoReader(videoAsset: videoAsset) else {
            throw TrackerProcessorError.readerInitializationFailed
        }
        
        guard let _ = videoReader.nextFrame() else {

            throw TrackerProcessorError.firstFrameReadFailed
        }
        
        var currentObservation = self.initialObservation
        
        boundingBoxes.append(currentObservation.boundingBox)
        
        let requestHandler = VNSequenceRequestHandler()
        
        while let frame = videoReader.nextFrame() {
            let trackingRequest = VNTrackObjectRequest(detectedObjectObservation: currentObservation)
            
            trackingRequest.trackingLevel = VNRequestTrackingLevel.accurate
            
            do {
                try requestHandler.perform([trackingRequest], on: frame, orientation: videoReader.orientation)
            } catch {
                throw TrackerProcessorError.objectTrackingFailed
            }
            
            guard let newObservation = trackingRequest.results?.first as? VNDetectedObjectObservation else {
                throw TrackerProcessorError.objectTrackingFailed
            }
            
            currentObservation = newObservation
            boundingBoxes.append(currentObservation.boundingBox)
        }
        
        return boundingBoxes
    }
}

