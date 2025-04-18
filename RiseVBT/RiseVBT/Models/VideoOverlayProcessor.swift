//
//  VideoOverlayProcessor.swift
//  VisionTest
//
//  Created by Jamshed Panthaki on 4/17/25.
//

import Foundation
import AVFoundation
import CoreGraphics
import CoreImage


public struct VideoOverlayProcessor {
    public init() {}
    
    public func process (
        inputURL: URL,
        outputURL: URL,
        overlayHandler: @escaping (CGContext, CGSize) -> Void
    ) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            overlayVideo(
                inputURL: inputURL,
                outputURL: outputURL,
                overlayHandler: overlayHandler,
                completion: { result in
                    switch result {
                    case .success(let url):
                        continuation.resume(returning: url)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            )
        }
    }
    
    public static func makeBoundingBoxHandler(
        boxes: [CGRect],
        color: CGColor,
        lineWidth: CGFloat = 2
    ) -> (CGContext, CGSize) -> Void {
        var frameIndex = 0
        return { ctx, size in
            guard frameIndex < boxes.count else { return }
            let nb = boxes[frameIndex]
            frameIndex += 1
            
            let rect = CGRect(
                x: nb.origin.x * size.width,
                y: nb.origin.y * size.height,
                width: nb.width    * size.width,
                height: nb.height  * size.height
            )
            ctx.setStrokeColor(color)
            ctx.setLineWidth(lineWidth)
            ctx.stroke(rect)
        }
    }
    
    public static func makePathHandler(
        boxes: [CGRect],
        color: CGColor,
        lineWidth: CGFloat = 2
    ) -> (CGContext, CGSize) -> Void {
        var index = 0
        var centers: [CGPoint] = []
        return { ctx, size in
            guard index < boxes.count else { return }
            let nb = boxes[index]
            index += 1
            let center = CGPoint(
                x: (nb.origin.x + nb.width/2) * size.width,
                y: (nb.origin.y + nb.height/2) * size.height
            )
            centers.append(center)
            
            guard centers.count > 1 else { return }
            ctx.setStrokeColor(color)
            ctx.setLineWidth(lineWidth)
            ctx.move(to: centers[0])
            for pt in centers.dropFirst() {
                ctx.addLine(to: pt)
            }
            ctx.strokePath()
        }
    }
    
    /// Creates a handler that draws both bounding boxes and the connecting path.
    public static func makeBoxAndPathHandler(
        boxes: [CGRect],
        boxColor: CGColor,
        pathColor: CGColor,
        lineWidth: CGFloat = 2
    ) -> (CGContext, CGSize) -> Void {
        var index = 0
        var centers: [CGPoint] = []
        return { ctx, size in
            guard index < boxes.count else { return }
            let nb = boxes[index]
            index += 1
            
            // box
            let rect = CGRect(
                x: nb.origin.x * size.width,
                y: nb.origin.y * size.height,
                width: nb.width    * size.width,
                height: nb.height  * size.height
            )
            ctx.setStrokeColor(boxColor)
            ctx.setLineWidth(lineWidth)
            ctx.stroke(rect)
            
            // accumulate center & draw path
            let center = CGPoint(
                x: (nb.origin.x + nb.width/2) * size.width,
                y: (nb.origin.y + nb.height/2) * size.height
            )
            centers.append(center)
            guard centers.count > 1 else { return }
            ctx.setStrokeColor(pathColor)
            ctx.move(to: centers[0])
            for pt in centers.dropFirst() {
                ctx.addLine(to: pt)
            }
            ctx.strokePath()
        }
    }
}

fileprivate func overlayVideo(
    inputURL: URL,
    outputURL: URL,
    overlayHandler: @escaping (CGContext, CGSize) -> Void,
    completion: @escaping (Result<URL, Error>) -> Void
) {
    let asset = AVAsset(url: inputURL)
    guard let track = asset.tracks(withMediaType: .video).first else {
        completion(.failure(NSError(domain: "Overlay", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "No video track"])))
        return
    }
    
    // calculate upright render size
    let natural = track.naturalSize.applying(track.preferredTransform)
    let size = CGSize(width: abs(natural.width), height: abs(natural.height))
    
    // build a composition that applies the track’s preferredTransform
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
    let layerInst = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
    layerInst.setTransform(track.preferredTransform, at: .zero)
    instruction.layerInstructions = [layerInst]
    
    let videoComp = AVMutableVideoComposition()
    videoComp.instructions = [instruction]
    videoComp.frameDuration = CMTime(value: 1, timescale: CMTimeScale(track.nominalFrameRate))
    videoComp.renderSize = size
    
    // reader that uses the video composition
    let reader = try! AVAssetReader(asset: asset)
    let readerOutput = AVAssetReaderVideoCompositionOutput(
        videoTracks: [track],
        videoSettings: [ kCVPixelBufferPixelFormatTypeKey as String:
                            kCVPixelFormatType_32BGRA ]
    )
    readerOutput.videoComposition = videoComp
    reader.add(readerOutput)
    
    // writer setup
    if FileManager.default.fileExists(atPath: outputURL.path) {
        try? FileManager.default.removeItem(at: outputURL)
    }
    let writer = try! AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: Int(size.width),
        AVVideoHeightKey: Int(size.height)
    ]
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    writerInput.expectsMediaDataInRealTime = false
    
    let attrs: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey  as String: Int(size.width),
        kCVPixelBufferHeightKey as String: Int(size.height)
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: writerInput,
        sourcePixelBufferAttributes: attrs
    )
    writer.add(writerInput)
    
    // start
    reader.startReading()
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    
    let queue = DispatchQueue(label: "video.overlay")
    writerInput.requestMediaDataWhenReady(on: queue) {
        while writerInput.isReadyForMoreMediaData {
            guard
                let sample = readerOutput.copyNextSampleBuffer(),
                let buffer = CMSampleBufferGetImageBuffer(sample)
            else {
                writerInput.markAsFinished()
                writer.finishWriting {
                    completion(writer.error.map(Result.failure) ?? .success(outputURL))
                }
                break
            }
            
            // draw original + overlay
            drawOverlay(on: buffer, size: size, using: overlayHandler)
            
            let pts = CMSampleBufferGetPresentationTimeStamp(sample)
            adaptor.append(buffer, withPresentationTime: pts)
        }
    }
}

fileprivate func drawOverlay(
    on pixelBuffer: CVPixelBuffer,
    size: CGSize,
    using handler: (CGContext, CGSize) -> Void
) {
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
    
    guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let info = CGBitmapInfo.byteOrder32Little.rawValue
    | CGImageAlphaInfo.premultipliedFirst.rawValue
    
    guard let ctx = CGContext(
        data: base,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: info
    ) else { return }
    
    // draw the upright frame
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let ciCtx   = CIContext()
    if let cgImg = ciCtx.createCGImage(ciImage, from: CGRect(origin: .zero, size: size)) {
        ctx.draw(cgImg, in: CGRect(origin: .zero, size: size))
    }
    
    // draw your boxes (origin=bottom‑left)
    handler(ctx, size)
}
