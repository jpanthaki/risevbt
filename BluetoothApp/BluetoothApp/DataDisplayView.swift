//
//  DataDisplayView.swift
//  BluetoothApp
//
//  Created by Jamshed Panthaki on 2/24/25.
//

import SwiftUI

struct DataDisplayView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Received Data:")
                .font(.headline)
            Text(bluetoothManager.receivedData)
                .font(.body)
                .padding()
                .border(Color.gray, width: 1)
            Spacer()
        }
        .padding()
        .navigationTitle("Data Display")
    }
}
