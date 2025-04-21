//
//  RecordView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/18/25.
//

import SwiftUI

struct RecordView: View {
    
    var accentColor: Color
    var navbarBackground: Color
    var backgroundColor: Color
    var preferDarkMode: Bool
    
    var videoOn: Bool = false
    
    var onStop: ([Packet], [Double], URL?) -> Void
    
    var onCancel: () -> Void
    
    @ObservedObject var service: BluetoothService
    
    @StateObject private var recorder = Recorder()

    @State private var isRecording = false
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack{
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    
                    if videoOn {
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(maxWidth: .infinity, minHeight: 300)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                            CameraPreview(session: $recorder.session)
                                .frame(maxWidth: .infinity, minHeight: 300)
                                .padding()
                        }
                    }
                    VStack {
                        Text("\(service.computedMCV != nil ? String(format: "%.2f", service.computedMCV ?? 0.0) : "–")")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(service.computedMCV != nil ? (service.computedMCV ?? 0.0 > 0.5 ? .green : .red) : .secondary)
                        Text("m/s")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 200, height: 120)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white).shadow(radius: 4))
                    
                    
                    HStack(spacing: 40) {
                        Button("Start") {
                            isRecording = true
                            service.sendStartCommand()
                            if videoOn {
                                recorder.startRecording()
                            }
                        }
                        .font(.headline)
                        .frame(width: 100, height: 44)
                        .background(isRecording && service.peripheralStatus.rawValue == "connected" && service.readyForCommand ? .gray : accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(isRecording || service.peripheralStatus.rawValue != "connected" || !service.readyForCommand)
                        
                        Button("Stop") {
                            isRecording = false
                            service.sendStopCommand()
                            if videoOn {
                                recorder.onFinishedRecording = { url in
                                    let packets = service.packets
                                    let mcvValues = service.mcvValues
                                    onStop(packets, mcvValues, url)
                                }
                                recorder.stopRecording()
                            } else {
                                let packets = service.packets
                                let mcvValues = service.mcvValues
                                onStop(packets, mcvValues, nil)
                            }
                        }
                        .font(.headline)
                        .frame(width: 100, height: 44)
                        .background(isRecording && service.peripheralStatus.rawValue == "connected" ? accentColor : .gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .disabled(!isRecording || service.peripheralStatus.rawValue != "connected")
                    }
                    if videoOn {
                        Spacer(minLength: 20)
                    }
                }
                .onAppear {
                    if videoOn {
                        recorder.startSession()
                    }
                    service.prepareForSession()
                }
                .onDisappear {
                    if videoOn {
                        recorder.stopSession()
                    }
                }
                .padding()
                .navigationTitle(service.peripheralStatus.rawValue)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(navbarBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            onCancel()
                        }
                        .disabled(isRecording)
                    }
                }
                .tint(accentColor)
            }
        }
        .preferredColorScheme(preferDarkMode ? .dark : .light)
    }
}

//#Preview {
//    RecordView(
//        accentColor: .blue,
//        navbarBackground: .blue.opacity(0.5),
//        backgroundColor: .white,
//        preferDarkMode: false,
//        videoOn: true
//    )
//}
