//
//  RecordViewVid.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/17/25.
//

import SwiftUI

struct RecordViewVid: View {
    
    @StateObject private var service = BluetoothService()
    @StateObject private var recorder = Recorder()
    
    @State private var showingAlert = false
    
    var body: some View {
        
        ZStack {
            Color.blue.opacity(0.5)
                .ignoresSafeArea()
            VStack {
                Text(service.peripheralStatus.rawValue)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                ZStack{
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.blue.opacity(0.4))
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.4))
                        VStack {
                            Text("\(String(format: "%.2f", service.computedMCV ?? 0.0))")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(service.computedMCV ?? 0.0 > 0.5 ? Color.green : Color.red)
                            
                            Text("m/s")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                }
                ZStack{
                    //video frame
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.blue.opacity(0.4))
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.4))
                        CameraPreview(session: $recorder.session)
                            .padding()
                    }
                    .padding()
                }
                .frame(minHeight: 500)
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.blue.opacity(0.4))
                    HStack {
                        Button {
                            if service.peripheralStatus.rawValue == "connected" {
                                if !recorder.isRecording {
                                    service.sendStartCommand()
                                    recorder.startRecording()
                                }
                            } else {
                                showingAlert = true
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.gray.opacity(0.4))
                                Text("Start")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.black)
                            }
                        }
                        .alert("Connect a Device First", isPresented: $showingAlert) {
                            Button("OK", role: .cancel) { }
                        }
                        Button {
                            if service.peripheralStatus.rawValue == "connected" {
                                if recorder.isRecording {
                                    service.sendStopCommand()
                                    recorder.stopRecording()
                                }
                            } else {
                                showingAlert = true
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.gray.opacity(0.4))
                                Text("Stop")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.black)
                            }
                        }
                        .alert("Connect a Device First", isPresented: $showingAlert) {
                            Button("OK", role: .cancel) { }
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
        
    }
}

#Preview {
    RecordViewVid()
}
