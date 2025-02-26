//
//  DeviceListView.swift
//  BluetoothApp
//
//  Created by Jamshed Panthaki on 2/24/25.
//

import SwiftUI
import CoreBluetooth

struct DeviceListView: View {
    @ObservedObject var bluetoothManager = BluetoothManager()
    
    var body: some View {
        NavigationStack {
            List(bluetoothManager.discoveredPeripherals, id: \.identifier) { peripheral in
                Button (action: {
                    bluetoothManager.connect(to: peripheral)
                }) {
                    Text(peripheral.name ?? "Unknown Device")
                }
            }
            .navigationTitle("Discovered Devices")
            .onAppear {
                bluetoothManager.startScanning()
            }
            .onDisappear {
                bluetoothManager.stopScanning()
            }
            .navigationDestination(isPresented: Binding<Bool>(
                get: { bluetoothManager.receivedData != "" },
                set: { _ in }
            )) {
                DataDisplayView(bluetoothManager: bluetoothManager)
            }
        }
    }
}
