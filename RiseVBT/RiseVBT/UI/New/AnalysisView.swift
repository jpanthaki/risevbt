//
//  AnalysisView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/19/25.
//

import SwiftUI
import Charts
import AVKit

struct DataPoint: Identifiable {
    let id = UUID()
    let time: Double
    let velocity: Double
}

struct AnalysisView: View {
    
    var accentColor: Color
    var navbarBackground: Color
    var backgroundColor: Color
    var preferDarkMode: Bool
    
    var model: DataModel
    var onClose: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                //video goes here if it's there
                if let url = model.processedVideoURL {
                    DataVisualizationWithVideo(model: model, accentColor: accentColor, videoURL: url)
                        .padding()
                } else {
                    DataVisualization(model: model, accentColor: accentColor)
                        .padding()
                }
            }
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onClose()
                    }
                }
            }
            .toolbarBackground(navbarBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(accentColor)
        }
        .preferredColorScheme(preferDarkMode ? .dark : .light)
    }
}
