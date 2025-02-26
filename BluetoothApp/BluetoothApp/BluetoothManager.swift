//
//  BluetoothManager.swift
//  BluetoothApp
//
//  Created by Jamshed Panthaki on 2/24/25.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject {
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var receivedData: String = ""
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    
    let espServiceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    let dataCharacteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")
    
    override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [espServiceUUID], options: nil)
            print("Scanning started...")
        } else {
            print("Bluetoth is not powered on")
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        print("Scanning stopped.")
    }
    
    func connect(to peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            startScanning()
        default:
            print("Bluetooth state changed to \(central.state)")
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(peripheral) {
            DispatchQueue.main.async {
                self.discoveredPeripherals.append(peripheral)
            }
            print("Discovered: \(peripheral.name ?? "Unknown")")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device")")
        
        peripheral.discoverServices([espServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "unknown error")")
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services where service.uuid == espServiceUUID {
                // Discover characteristic for data
                peripheral.discoverCharacteristics([dataCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics where characteristic.uuid == dataCharacteristicUUID {
                // Subscribe for updates
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let data = characteristic.value {
            // Assume data is a UTF8 string for this example
            if let dataString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.receivedData = dataString
                }
                print("Received data: \(dataString)")
            }
        }
    }
}
