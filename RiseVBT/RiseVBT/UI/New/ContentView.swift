//
//  ContentView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/18/25.
//

import SwiftUI
import SwiftData

struct Theme {
    var accentColor: Color = .orange
    var navbarBackground: Color = .blue.opacity(0.5)
    var backgroundColor: Color = Color(UIColor.systemGroupedBackground)
    var isDarkMode: Bool = false
}

struct ContentView: View {
    let theme = Theme()
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DataModel.createdAt) private var entries: [DataModel]
    
    @StateObject private var btService = BluetoothService()
    
    @State private var showBasicRecord = false
    @State private var showVideoRecord = false
    @State private var showForm = false
    @State private var showAnalysis = false
    
    @State private var packetArray: [Packet]?
    @State private var mcvArray: [Double]?
    @State private var videoURL: URL?
    
    @State private var selectedModel: DataModel?
    
    var body: some View {
        NavigationStack {
            MainView(
                accentColor: theme.accentColor,
                navbarBackground: theme.navbarBackground,
                backgroundColor: theme.backgroundColor,
                preferDarkMode: theme.isDarkMode,
                entries: entries,
                onBasicRecord: {
                    showBasicRecord = true
                },
                onVideoRecord: {
                    showVideoRecord = true
                },
                onSelect: { model in
                    selectedModel = model
                    print(selectedModel?.lift.rawValue ?? "NONE")
                    showAnalysis = true
                },
                onDelete: { model in
                    modelContext.delete(model)
                },
                service: btService
            )
        }
        .fullScreenCover(isPresented: $showBasicRecord) {
            RecordView(
                accentColor: theme.accentColor,
                navbarBackground: theme.navbarBackground,
                backgroundColor: theme.backgroundColor,
                preferDarkMode: theme.isDarkMode,
                videoOn: false,
                onStop: { packets, mcvValues, _ in
                    packetArray = packets
                    mcvArray = mcvValues
                    videoURL = nil
                    showBasicRecord = false
                    showForm = true
                },
                onCancel: {
                    showBasicRecord = false
                },
                service: btService
            )
            .interactiveDismissDisabled(true)
        }
        .fullScreenCover(isPresented: $showVideoRecord) {
            RecordView(
                accentColor: theme.accentColor,
                navbarBackground: theme.navbarBackground,
                backgroundColor: theme.backgroundColor,
                preferDarkMode: theme.isDarkMode,
                videoOn: true,
                onStop: { packets, mcvValues, url in
                    packetArray = packets
                    mcvArray = mcvValues
                    videoURL = url
                    showVideoRecord = false
                    showForm = true
                },
                onCancel: {
                    showVideoRecord = false
                },
                service: btService
            )
            .interactiveDismissDisabled(true)
        }
        .fullScreenCover(isPresented: $showForm) {
            FormView(
                accentColor: theme.accentColor,
                navbarBackground: theme.navbarBackground,
                backgroundColor: theme.backgroundColor,
                preferDarkMode: theme.isDarkMode,
                packets: packetArray,
                mcvValues: mcvArray,
                videoURL: videoURL,
                onSave: { model in
                    modelContext.insert(model)
                    showForm = false
                },
                onCancel: {
                    showForm = false
                }
            )
            .interactiveDismissDisabled(true)
        }
        .fullScreenCover(item: $selectedModel) { model in
            AnalysisView(
                accentColor: theme.accentColor,
                navbarBackground: theme.navbarBackground,
                backgroundColor: theme.backgroundColor,
                preferDarkMode: theme.isDarkMode,
                model: model,
                onClose: {
                    showAnalysis = false
                    selectedModel = nil
                }
            )
        }
    }
}

#Preview {
    ContentView()
}
