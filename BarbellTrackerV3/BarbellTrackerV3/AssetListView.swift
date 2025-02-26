//
//  AssetListView.swift
//  BarbellTrackerV3
//
//  Created by Jamshed Panthaki on 2/22/25.
//

import SwiftUI
import Photos

struct AssetListView: View {
    // view model that stores video assets
    @StateObject private var viewModel = AssetListViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.assets, id: \.localIdentifier) { asset in
                
                // when we click on an list item, navigate to next view
                NavigationLink(destination: VideoPlayerView(asset: asset)) {
                    AssetThumbnailView(asset: asset)
                }
                .navigationTitle("Select a Video")
            }
        }
        .onAppear {
            //load assets on appearance
            viewModel.requestAndLoadAssets()
        }
    }
}

// model to fetch view assets from photos library
class AssetListViewModel: ObservableObject {
    // store fetched PHAsset objects
    @Published var assets: [PHAsset] = []
    
    // request permission from user, then load video assets
    func requestAndLoadAssets() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                //we go in here only if photos access is authorized
                
                let options = PHFetchOptions() //fetch options and set sorting key
                options.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
                
                //fetch the videos from photos
                let fetchResult = PHAsset.fetchAssets(with: .video, options: options)
                var loadedAssets: [PHAsset] = []
                
                //append all results to loadedAssets
                fetchResult.enumerateObjects { asset, _, _ in
                    loadedAssets.append(asset)
                }
                
                // update assets property on main thread
                DispatchQueue.main.async {
                    self.assets = loadedAssets
                }
            }
        }
    }
}

//display thumbnail for video asset
struct AssetThumbnailView: View {
    let asset: PHAsset
    
    //hold the thumbnail image
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        Group {
            //if a thumbnail exists, use it, else gray
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray
            }
        }
        .frame(width: 100, height: 100)
        .clipped()
        .onAppear {
            
            //use photos framework to display the image
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true // can grab from iCloud if necessary
            options.deliveryMode = .opportunistic
            manager.requestImage(for: asset,
                                 targetSize: CGSize(width: 100, height: 100),
                                 contentMode: .aspectFill,
                                 options: options) { image, _ in
                self.thumbnail = image //store the image here
            }
        }
    }
}

#Preview {
    AssetListView()
}
