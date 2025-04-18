//
//  ContentView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/18/25.
//

import SwiftUI

struct Theme {
    var accentColor: Color = .orange
    var navbarBackground: Color = .blue.opacity(0.5)
    var backgroundColor: Color = Color(UIColor.systemGroupedBackground)
    var isDarkMode: Bool = false
}

struct ContentView: View {
    let theme = Theme()
    
    @StateObject private var btService = BluetoothService()
    
    @State private var showBasicRecord = false
    @State private var showVideoRecord = false
    
    @State private var packetArray: [Packet]?
    @State private var videoURL: URL?
    
    var body: some View {
        NavigationStack {
            MainView(
                accentColor: theme.accentColor,
                navbarBackground: theme.navbarBackground,
                backgroundColor: theme.backgroundColor,
                preferDarkMode: theme.isDarkMode,
                onBasicRecord: {
                    showBasicRecord = true
                },
                onVideoRecord: {
                    showVideoRecord = true
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
                onStop: { packets, _ in
                    packetArray = packets
                    videoURL = nil
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
                onStop: { packets, url in
                    packetArray = packets
                    videoURL = url
                    print("GOT URL")
                    print(videoURL ?? "bruh")
                    showVideoRecord = false
                },
                service: btService
            )
            .interactiveDismissDisabled(true)
        }
    }
}

#Preview {
    ContentView()
}
