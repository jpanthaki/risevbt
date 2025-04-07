//
//  _VideoWriter.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 3/26/25.
//

import AVFoundation
import CoreGraphics
import Darwin
import Foundation

/// A helper class that constructs a video file by appending frames with bounding boxes.
public class _VideoWriter {
    
    private var assetWriter: AVAssetWriter
    private var videoInput: AVAssetWriterInput
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    
    private var frameCount: Int64 = 0
    private let frameDuration: CMTime
    
    private let outputURL: URL
    private let renderSize: CGSize
    
    // MARK: - Init
    
    /// - Parameters:
    ///   - outputURL: The file URL for the output movie.
    ///   - renderSize: The video resolution (e.g., 1280x720).
    ///   - fps: Desired frames per second.
    ///   - fileType: AVFileType for the output (e.g., .mov).
    public init(outputURL: URL,
                renderSize: CGSize,
                fps: Int32 = 30,
                fileType: AVFileType = .mov) throws {
        
        self.outputURL = outputURL
        self.renderSize = renderSize
        self.frameDuration = CMTime(value: 1, timescale: fps)
        
        // Remove existing file if necessary
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
        
        // Setup video settings
        let compressionSettings: [String: Any] = [
            AVVideoAverageBitRateKey: 6_000_000,
        ]
        
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: renderSize.width,
            AVVideoHeightKey: renderSize.height,
            AVVideoCompressionPropertiesKey: compressionSettings
        ]
        
        // Create the input
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        videoInput.expectsMediaDataInRealTime = false
        
        // Create the pixel buffer adaptor
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: renderSize.width,
                kCVPixelBufferHeightKey as String: renderSize.height
            ]
        )
        
        // Add input to writer
        guard assetWriter.canAdd(videoInput) else {
            throw VideoWriterError.unableToAddInput
        }
        assetWriter.add(videoInput)
    }
    
    // MARK: - Lifecycle
    
    /// Starts the writing session.
    public func start() throws {
        guard assetWriter.status == .unknown else {
            throw VideoWriterError.invalidStatusForStart
        }
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
    }
    
    /// Appends a single video frame.
    /// - Parameters:
    ///   - cgImage: The input frame as a `CGImage`.
    ///   - boundingBox: The bounding box to draw on the frame, in video coordinates.
    /// - Returns: A boolean indicating whether the frame could be appended.
    public func appendFrame(_ cgImage: CGImage, boundingBox: CGRect) -> Bool {
        guard videoInput.isReadyForMoreMediaData else {
            return false
        }
        
        // Create pixel buffer
        guard let pixelBuffer = createPixelBuffer(from: cgImage) else {
            return false
        }
        
        // Draw bounding box on the pixel buffer
        drawBoundingBox(boundingBox, on: pixelBuffer)
        
        // Compute presentation time
        let presentationTime = CMTime(value: frameCount, timescale: frameDuration.timescale)
        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        
        frameCount += 1
        return true
    }
    
    /// Finishes writing the video and completes the file.
    /// - Parameter completion: Called when writing completes or fails.
    public func finish(completion: @escaping (Result<URL, Error>) -> Void) {
        videoInput.markAsFinished()
        assetWriter.finishWriting { [weak self] in
            guard let self = self else { return }
            if self.assetWriter.status == .completed {
                completion(.success(self.outputURL))
            } else {
                completion(.failure(self.assetWriter.error ?? VideoWriterError.unknown))
            }
        }
    }
    
    // MARK: - Private helpers
    
    /// Creates a new CVPixelBuffer from the given CGImage.
    private func createPixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
        guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else {
            return nil
        }
        
        var pixelBufferOut: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            pixelBufferPool,
            &pixelBufferOut
        )
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        // Create CGContext that writes into CVPixelBuffer
        if let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(renderSize.width),
            height: Int(renderSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) {
            // Flip the context coordinate system for drawing
            context.translateBy(x: 0, y: CGFloat(renderSize.height))
            context.scaleBy(x: 1.0, y: -1.0)
            
            // Draw the image
            let drawRect = CGRect(origin: .zero, size: renderSize)
            context.draw(cgImage, in: drawRect)
        }
        
        return pixelBuffer
    }
    
    /// Draws the bounding box onto the existing pixel buffer using CoreGraphics.
    private func drawBoundingBox(_ boundingBox: CGRect, on pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(renderSize.width),
            height: Int(renderSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return
        }
        
        // Flip context so we can draw in "normal" coordinate space
        context.translateBy(x: 0, y: renderSize.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Set bounding box stroke
        context.setLineWidth(3.0)
        context.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)) // Red bounding box
        
        context.stroke(boundingBox)
    }
}

// MARK: - VideoWriterError

public enum VideoWriterError: Error {
    case unableToAddInput
    case invalidStatusForStart
    case unknown
}

