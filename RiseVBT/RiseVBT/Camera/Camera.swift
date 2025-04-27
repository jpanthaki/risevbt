//
//  Camera.swift
//  CameraTest
//
//
//  Created by Jamshed Panthaki on 4/16/25.
//  Adapted from https://www.kodeco.com/books/swiftui-cookbook/v1.0/chapters/5-recording-audio-video-in-swiftui

import AVFoundation
import Photos
import SwiftUI
import UIKit


final class PreviewView: UIView {
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

struct CameraPreview: UIViewRepresentable {
    @Binding var session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

class Recorder: NSObject, AVCaptureFileOutputRecordingDelegate, ObservableObject {
    @Published var session = AVCaptureSession() // session is now @Published
    @Published var isRecording = false
    @Published var recordingURL: URL? = nil
    
    var onFinishedRecording: ((URL) -> Void)?
    
    private let movieOutput = AVCaptureMovieFileOutput()
    
    override init() {
        super.init()
        addAudioInput()
        addVideoInput()
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        session.stopRunning()
    }
    
    private func addAudioInput() {
        guard let device = AVCaptureDevice.default(for: .audio) else { return }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) {
            session.addInput(input)
        }
    }
    
    private func addVideoInput() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) {
            session.addInput(input)
        }
    }
    
    func startRecording() throws {
        let url = try makeNewVideoURL()
        if movieOutput.isRecording == false {
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            movieOutput.startRecording(to: url, recordingDelegate: self)
            isRecording = true
        }
    }
    
    func stopRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
            isRecording = false
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        // Handle actions when recording starts
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Check for recording error
        if let error = error {
            print("Error recording: \(error.localizedDescription)")
            return
        }
        
        DispatchQueue.main.async {
            print("sending url to view", outputFileURL)
            self.onFinishedRecording?(outputFileURL)
        }
        
        // Save video to Photos
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        }) { saved, error in
            if saved {
                print(outputFileURL)
                print("Successfully saved video to Photos.")
            } else if let error = error {
                print("Error saving video to Photos: \(error.localizedDescription)")
            }
        }
    }
}


