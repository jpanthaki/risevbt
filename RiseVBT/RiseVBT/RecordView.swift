//
//  RecordView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/14/25.
//

import SwiftUI
import Charts


struct RecordView : View {
    
    @StateObject var service = BluetoothService()
    
    var body: some View {
        
        ZStack {
            Color.blue.opacity(0.5)
                .ignoresSafeArea()
            Text("RECORD")
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
    RecordView()
}
