//
//  MainView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/18/25.
//

import SwiftUI

struct MainView: View {
    
    var accentColor: Color
    var navbarBackground: Color
    var backgroundColor: Color
    var preferDarkMode: Bool
    
    var onBasicRecord: () -> Void
    var onVideoRecord: () -> Void
    
    @ObservedObject var service: BluetoothService
    
    @State private var showingHelp: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                //this is where the list of entries will go.
                Text("No entries yet - tap + to record")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .navigationTitle("RiseVBT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(navbarBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(accentColor)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Record Lift (with video)") {
                            onVideoRecord()
                        }
                        Button("Record Lift (no video)") {
                            onBasicRecord()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .alert("Instructions:", isPresented: $showingHelp) {
                Button("Dismiss", role: .cancel) {
                    showingHelp = false
                }
            } message: {
                Text("Use + to start recording. Upon completion, fill out the form and view analysis.")
            }
        }
        .preferredColorScheme(preferDarkMode ? .dark : .light)
    }
}
