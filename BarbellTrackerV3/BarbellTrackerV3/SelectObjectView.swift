//
//  SelectObjectView.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 3/13/25.
//

import SwiftUI
import Photos

struct SelectObjectView: View {
    let videoAsset: PHAsset
    
    @State private var avAsset: AVAsset? = nil
    @State private var firstFrame: UIImage? = nil
    
    @State private var selectionRect: CGRect = .zero
    @State private var normalizedSelectionRect: CGRect = .zero
    @State private var startLocation: CGPoint? = nil
    @State private var isDragging: Bool = false
    
    @State private var startProcessing = false
    
    
    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    Text("x: \(String(format: "%.2f", selectionRect.origin.x)), y: \(String(format: "%.2f", selectionRect.origin.y))")
                    Text("w: \(String(format: "%.2f", selectionRect.width)), h: \(String(format: "%.2f", selectionRect.height))")
                }
                .padding()
                
                VStack {
                    Text("x: \(String(format: "%.2f", normalizedSelectionRect.origin.x)), y: \(String(format: "%.2f", normalizedSelectionRect.origin.y))")
                    Text("w: \(String(format: "%.2f", normalizedSelectionRect.width)), h: \(String(format: "%.2f", normalizedSelectionRect.height))")
                }
                .padding()
                
                if let image = firstFrame {
                    GeometryReader { geometry in
                        let containerSize = geometry.size
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: containerSize.width, height: containerSize.height)
                                .clipped()
                            
                            if isDragging || selectionRect != .zero {
                                Rectangle()
                                    .stroke(Color.red, lineWidth: 2)
                                    .frame(width: selectionRect.width, height: selectionRect.height)
                                    .position(x: selectionRect.midX, y: selectionRect.midY)
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if startLocation == nil {
                                        startLocation = value.startLocation
                                    }
                                    isDragging = true
                                    let currentLocation = value.location
                                    // Calculate rectangle relative to the image's geometry.
                                    let origin = CGPoint(x: min(startLocation!.x, currentLocation.x),
                                                         y: min(startLocation!.y, currentLocation.y))
                                    let size = CGSize(width: abs(startLocation!.x - currentLocation.x),
                                                      height: abs(startLocation!.y - currentLocation.y))
                                    selectionRect = CGRect(origin: origin, size: size)
                                    
//                                    normalizedSelectionRect = CGRect(
//                                        x: selectionRect.origin.x / geometry.size.width,
//                                        y: selectionRect.origin.y / geometry.size.height,
//                                        width: selectionRect.width / geometry.size.width,
//                                        height: selectionRect.height / geometry.size.height
//                                    )
                                    normalizedSelectionRect = CGRect(
                                        x: selectionRect.origin.x / geometry.size.width,
                                        y: 1.0 - (selectionRect.origin.y + selectionRect.height) / geometry.size.height,
                                        width: selectionRect.width / geometry.size.width,
                                        height: selectionRect.height / geometry.size.height
                                    )
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                    }
                } else {
                    ProgressView("Loading First Frame...")
                }
                
                HStack {
                    Button(action : {
                        selectionRect = .zero
                        normalizedSelectionRect = .zero
                        startLocation = nil
                    }) {
                        Text("Clear Selection")
                    }
                    .padding()
                    Button(action: {
                        if normalizedSelectionRect != .zero {
                            startProcessing = true
                        }
                    }) {
                        Text("Process Video...")
                            .padding()
                            .background(normalizedSelectionRect != .zero ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                
            }
            .onAppear {
                loadAVAsset()
            }
            .navigationTitle("Select an Object to Track:")
            .navigationDestination(isPresented: $startProcessing) {
                if let avAsset = avAsset {
                    ProcessingView(phAsset: videoAsset, videoAsset: avAsset, initialRect: normalizedSelectionRect)
                }
            }
        }
        
    }
    
    private func loadAVAsset() {
        PHImageManager.default().requestAVAsset(forVideo: videoAsset, options: nil) { asset, audioMix, info in
            if let asset = asset {
                DispatchQueue.main.async {
                    self.avAsset = asset
                    loadFirstFrame(from: asset)
                }
            }
        }
    }
    
    private func loadFirstFrame(from asset: AVAsset) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let reader = VideoReader(videoAsset: asset),
                  let pixelBuffer = reader.nextFrame() else {
                return
            }
            
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                DispatchQueue.main.async{
                    self.firstFrame = uiImage
                }
            }
        }
    }
}

struct SelectObjectViewPhoto: View {
    var image: UIImage?
    
    @State private var selectionRect: CGRect = .zero
    @State private var normalizedSelectionRect: CGRect = .zero
    @State private var startLocation: CGPoint? = nil
    @State private var isDragging: Bool = false
    
    @State private var showTestOverlay = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Select an object to track").padding()
                VStack {
                    Text("x: \(String(format: "%.2f", selectionRect.origin.x)), y: \(String(format: "%.2f", selectionRect.origin.y))")
                    Text("w: \(String(format: "%.2f", selectionRect.width)), h: \(String(format: "%.2f", selectionRect.height))")
                }
                VStack {
                    Text("x: \(String(format: "%.2f", normalizedSelectionRect.origin.x)), y: \(String(format: "%.2f", normalizedSelectionRect.origin.y))")
                    Text("w: \(String(format: "%.2f", normalizedSelectionRect.width)), h: \(String(format: "%.2f", normalizedSelectionRect.height))")
                }
                GeometryReader { geometry in
                    
                    ZStack {
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
//                                .scaledToFit()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        } else {
                            Color.gray
                        }
                        if isDragging || selectionRect != .zero {
                            Rectangle()
                                .stroke(Color.red, lineWidth: 2)
                                .frame(width: selectionRect.width, height: selectionRect.height)
                                .position(x: selectionRect.midX, y: selectionRect.midY)
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if startLocation == nil {
                                    startLocation = value.startLocation
                                }
                                isDragging = true
                                let currentLocation = value.location
                                // Calculate rectangle relative to the image's geometry.
                                let origin = CGPoint(x: min(startLocation!.x, currentLocation.x),
                                                     y: min(startLocation!.y, currentLocation.y))
                                let size = CGSize(width: abs(startLocation!.x - currentLocation.x),
                                                  height: abs(startLocation!.y - currentLocation.y))
                                selectionRect = CGRect(origin: origin, size: size)
                                
                                normalizedSelectionRect = CGRect(
                                    x: selectionRect.origin.x / geometry.size.width,
                                    y: selectionRect.origin.y / geometry.size.height,
                                    width: selectionRect.width / geometry.size.width,
                                    height: selectionRect.height / geometry.size.height
                                )
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                }
                Button(action: {
                    // Make sure there's a non-zero selection before navigating.
                    if normalizedSelectionRect != .zero {
                        showTestOverlay = true
                    }
                }) {
                    Text("Test Overlay")
                        .padding()
                        .background(normalizedSelectionRect != .zero ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top)
                
                
                Button(action : {
                    selectionRect = .zero
                    normalizedSelectionRect = .zero
                    startLocation = nil
                }) {
                    Text("Clear Selection")
                }
                .padding()
            }
            .navigationTitle("Select Object")
            .navigationDestination(isPresented: $showTestOverlay) {
                TestOverlayView(image: image!, overlayRect: normalizedSelectionRect)
            }
        }
    }
}

struct TestOverlayView: View {
    // The image to display.
    var image: UIImage
    // The rectangle that should be overlaid on the image.
    // This is expected to be in the coordinate space of the displayed image.
    var overlayRect: CGRect
    
    var body: some View {
        VStack{
            VStack {
                Text("x: \(String(format: "%.2f", overlayRect.origin.x)), y: \(String(format: "%.2f", overlayRect.origin.y))")
                Text("w: \(String(format: "%.2f", overlayRect.width)), h: \(String(format: "%.2f", overlayRect.height))")
            }
            GeometryReader { geometry in
                
                let containerSize = geometry.size
                // The image is scaled to fit the available space.
                let imageView = Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            
                let actualRect = CGRect(
                    x: overlayRect.origin.x * containerSize.width,
                    y: overlayRect.origin.y * containerSize.height,
                    width: overlayRect.width * containerSize.width,
                    height: overlayRect.height * containerSize.height
                )
                
                ZStack {
                    imageView
                    
                    // Draw the overlay rectangle.
                    Rectangle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: actualRect.width, height: actualRect.height)
                        .position(x: actualRect.midX, y: actualRect.midY)
                }
            }
            // Optionally, constrain the view to a specific aspect ratio.
            .aspectRatio(1, contentMode: .fit)
        }
    }
}

#Preview {
    SelectObjectViewPhoto(image: UIImage(named: "sampleImage"))
}
