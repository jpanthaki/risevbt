//
//  RecordView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/14/25.
//

import SwiftUI

struct RecordViewNoVid : View {
    
    @StateObject var service = BluetoothService()
    
    var body: some View {
        
        ZStack {
            Color.blue.opacity(0.5)
                .ignoresSafeArea()
            VStack {
                Text(service.peripheralStatus.rawValue)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 30)
                    .padding(.bottom, 30)
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
                .padding(.bottom, 10)
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.blue.opacity(0.4))
                    HStack {
                        Button {
                            if service.peripheralStatus.rawValue == "connected" {
                                service.sendStartCommand()
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.gray.opacity(0.4))
                                Text("Start\nRecording")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.black)
                            }
                        }
                        Button {
                            if service.peripheralStatus.rawValue == "connected" {
                                service.sendStopCommand()
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.gray.opacity(0.4))
                                Text("Stop\nRecording")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.black)
                            }
                        }
                    }
                    .padding()
                }
                .padding(.bottom, 10)
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.blue.opacity(0.4))
                    Button {
                        
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.4))
                            Text("Go to Analysis")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color.black)
                        }
                    }
                    .padding()
                }
                .padding(.bottom, 100)
            }
            .padding()
        }
        
    }
}

struct RecordViewThatWorks: View {
    @StateObject var service = BluetoothService()
    
    var body: some View {
        
        ZStack{
            Color.blue.opacity(0.5)
                .ignoresSafeArea()
            VStack {
                Text(service.peripheralStatus.rawValue)
                    .font(.title)
                
                if service.peripheralStatus.rawValue == "connected" {
                    //view
                    VStack {
                        Text("\(service.computedMCV ?? 0.0)")
                        HStack {
                            Button("StartButton") {
                                service.sendStartCommand()
                            }
                            Button("StopButton") {
                                service.sendStopCommand()
                            }
                        }
                    }
                    
                    
                } else {
                    EmptyView()
                }
            }
            .padding()
        }
        
    }
}

#Preview {
    RecordViewNoVid()
}
