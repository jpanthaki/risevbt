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
    
    var entries: [DataModel]
    
    var onBasicRecord: () -> Void
    var onVideoRecord: () -> Void
    
    var onSelect: (DataModel) -> Void
    var onDelete: (DataModel) -> Void
    
    @ObservedObject var service: BluetoothService
    
    @State private var showingHelp: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                
                if entries.isEmpty {
                    Text("No entries yet – tap + to record")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    List {
                        ForEach(entries) { model in
                            Button {
                                onSelect(model)
                            } label: {
                                VStack {
                                    HStack {
                                        Text(model.createdAt, style: .date)
                                        Spacer()
                                        Text(model.lift.rawValue)
                                    }
                                    HStack {
                                        Text("\(model.weight, format: .number) \(model.standard.rawValue)")
                                        Spacer()
                                        Text("\(model.rpe, format: .number)")
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                onDelete(entries[index])
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
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
                    Menu {
                        Text("\(service.peripheralStatus.rawValue)")
                    } label: {
                        Image(systemName: "info.circle")
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
