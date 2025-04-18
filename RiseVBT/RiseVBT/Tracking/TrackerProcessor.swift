//
//  TrackerProcessor.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 3/13/25.
//

import AVFoundation
import Vision
import CoreML

enum TrackerProcessorError: Error {
    case readerInitializationFailed
    case firstFrameReadFailed
    case objectTrackingFailed
}

class TrackerProcessor {
    let videoAsset: AVAsset
    private let detectionModel: VNCoreMLModel
    
    var initialObservation: VNDetectedObjectObservation
    var boundingBoxes: [CGRect] = []
    
    init(videoAsset: AVAsset, initialBoundingBox: CGRect? = nil, modelConfig: MLModelConfiguration = .init()) throws {
        self.videoAsset = videoAsset
        
        let detector = try PlateDetector(configuration: modelConfig)
        self.detectionModel = try VNCoreMLModel(for: detector.model)
        
        
        if let box = initialBoundingBox {
            self.initialObservation = VNDetectedObjectObservation(boundingBox: box)
        } else {
            // placeholder; we’ll replace this below before tracking
            self.initialObservation = VNDetectedObjectObservation(boundingBox: .zero)
        }
    }
    
    private lazy var detectionRequest: VNCoreMLRequest = {
        let req = VNCoreMLRequest(model: detectionModel) { req, err in
            // we’ll grab results manually below
        }
        // scale the image to fit the model’s input
        req.imageCropAndScaleOption = .scaleFill
        return req
    }()
    
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
        
        let requestHandler = VNSequenceRequestHandler()
        
        guard let firstFrame = videoReader.nextFrame() else {
            throw TrackerProcessorError.firstFrameReadFailed
        }
        
        try requestHandler.perform(
            [detectionRequest],
            on: firstFrame,
            orientation: videoReader.orientation
        )
        
        guard let detections = detectionRequest.results as? [VNRecognizedObjectObservation],
              let best = detections.max(by: { $0.confidence < $1.confidence })
        else {
            throw TrackerProcessorError.objectTrackingFailed
        }
        
        var currentObservation = VNDetectedObjectObservation(boundingBox: best.boundingBox)
        boundingBoxes = [ currentObservation.boundingBox ]
        
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
            
            if newObservation.confidence < 0.5 {
                try requestHandler.perform(
                    [detectionRequest],
                    on: frame,
                    orientation: videoReader.orientation
                )
                if let fallback = (detectionRequest.results as? [VNRecognizedObjectObservation])?
                    .max(by: { $0.confidence < $1.confidence }) {
                    currentObservation = VNDetectedObjectObservation(boundingBox: fallback.boundingBox)
                }
            }

        }

        return boundingBoxes
    }
}

