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

enum ActiveSheet: Identifiable {
    case basic
    case video
    case form(packets: [Packet]?, mcvValues: [Double]?, url: URL?)
    case analysis(DataModel)
    
    var id: String {
        switch self {
        case .basic : return "basic"
        case .video : return "video"
        case .form: return "form"
        case .analysis: return "analysis"
        }
    }
}

struct ContentView: View {
    let theme = Theme()
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DataModel.createdAt) private var entries: [DataModel]
    
    @StateObject private var btService = BluetoothService()
    
//    @State private var showBasicRecord = false
//    @State private var showVideoRecord = false
//    @State private var showForm = false
//    @State private var showAnalysis = false
    
    @State private var activeSheet: ActiveSheet?
    
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
                    activeSheet = .basic
                },
                onVideoRecord: {
                    activeSheet = .video
                },
                onSelect: { model in
                    selectedModel = model
                    print(selectedModel?.lift.rawValue ?? "NONE")
                    activeSheet = .analysis(model)
                },
                onDelete: { model in
                    modelContext.delete(model)
                },
                service: btService
            )
        }
        .fullScreenCover(item: $activeSheet) { sheet in
            switch sheet {
            case .basic:
                RecordView(
                    accentColor: theme.accentColor,
                    navbarBackground: theme.navbarBackground,
                    backgroundColor: theme.backgroundColor,
                    preferDarkMode: theme.isDarkMode,
                    videoOn: false,
                    onStop: { packets, mcvValues, _ in
                        activeSheet = .form(
                            packets: packets,
                            mcvValues: mcvValues,
                            url: nil
                        )
                    },
                    onCancel: {
                        activeSheet = nil
                    },
                    service: btService
                )
            case .video:
                RecordView(
                    accentColor: theme.accentColor,
                    navbarBackground: theme.navbarBackground,
                    backgroundColor: theme.backgroundColor,
                    preferDarkMode: theme.isDarkMode,
                    videoOn: true,
                    onStop: { packets, mcvValues, url in
                        activeSheet = .form(
                            packets: packets,
                            mcvValues: mcvValues,
                            url: url
                        )
                    },
                    onCancel: {
                        activeSheet = nil
                    },
                    service: btService
                )
            case .form(let packets, let mcvValues, let url):
                FormView(
                    accentColor: theme.accentColor,
                    navbarBackground: theme.navbarBackground,
                    backgroundColor: theme.backgroundColor,
                    preferDarkMode: theme.isDarkMode,
                    packets: packets,
                    mcvValues: mcvValues,
                    videoURL: url,
                    onSave: { model in
                        modelContext.insert(model)
                        activeSheet = nil
                    },
                    onCancel: {
                        activeSheet = nil
                    }
                )
            case .analysis(let model):
                AnalysisView(
                    accentColor: theme.accentColor,
                    navbarBackground: theme.navbarBackground,
                    backgroundColor: theme.backgroundColor,
                    preferDarkMode: theme.isDarkMode,
                    model: model,
                    onClose: {
                        activeSheet = nil
                    }
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
