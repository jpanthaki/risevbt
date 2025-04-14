//
//  BluetoothService.swift
//  BluetoothApp
//
//  Created by Jamshed Panthaki on 4/8/25.
//

import Foundation
import CoreBluetooth

enum ConnectionStatus: String {
    case connected
    case disconnected
    case scanning
    case connecting
    case error
}

let myService: CBUUID = CBUUID(string: "7c961cfd-2527-4808-a9b0-9ce954427712")
let dataCharacteristicUUID: CBUUID = CBUUID(string: "207a2a33-ab38-4748-8702-5ff50b2d673f")
let commandCharacteristicUUID: CBUUID = CBUUID(string: "1c902c8d-88bb-44f9-9dea-0bc5bf2d0af4")

class BluetoothService: NSObject, ObservableObject {
    
    private var centralManager: CBCentralManager!
    
    var myPeripheral: CBPeripheral?

    var commandCharacteristic: CBCharacteristic?
    
    @Published var peripheralStatus: ConnectionStatus = .disconnected
    @Published var packets: [Packet] = []
//    @Published var currPacket: Data = Data()
    @Published var currPacket: String = ""
    @Published var computedMCV: Double?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func scanForPeripherals() {
        peripheralStatus = .scanning
        centralManager.scanForPeripherals(withServices: [myService])
    }

    func sendStartCommand() {
        guard let peripheral: CBPeripheral = myPeripheral,
              let commandCharacteristic: CBCharacteristic = commandCharacteristic else {
            print("Cannot send start command, missing peripheral or command characteristic")
            return 
        }

        let command: String = "start"
        guard let data = command.data(using: .utf8) else {
            print("Failed to convert command to data")
            return
        }

        peripheral.writeValue(data, for: commandCharacteristic, type: .withResponse)
        print("Sent start command: \(command)")
    }
    
    func sendStopCommand() {
        guard let peripheral: CBPeripheral = myPeripheral,
              let commandCharacteristic: CBCharacteristic = commandCharacteristic else {
            print("Cannot send stop command, missing peripheral or command characteristic")
            return
        }
        
        let command: String = "stop"
        guard let data = command.data(using: .utf8) else {
            print("Failed to convert command to data")
            return
        }
        
        peripheral.writeValue(data, for: commandCharacteristic, type: .withResponse)
        print("Sent stop command: \(command)")
    }
}

extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("CB Powered On")
            scanForPeripherals()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name != nil {
            print(peripheral.name!)
        }
        if peripheral.name == "sheeeeeed" {
            print("Discovered \(peripheral.name ?? "unknown")")
            myPeripheral = peripheral
            centralManager.connect(myPeripheral!)
            peripheralStatus = .connecting
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheralStatus = .connected
        
        peripheral.delegate = self
        peripheral.discoverServices([myService])
        centralManager.stopScan()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        peripheralStatus = .disconnected
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        peripheralStatus = .error
        print(error?.localizedDescription ?? "no error")
    }
}

extension BluetoothService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            if service.uuid == myService {
                print("found service for \(myService)")
                peripheral.discoverCharacteristics([dataCharacteristicUUID, commandCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            print("Discovered characteristic: \(characteristic.uuid.uuidString)")
            if characteristic.uuid == dataCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
                print("Found data characteristic, waiting on values.")
            } else if characteristic.uuid == commandCharacteristicUUID {
                // Store the command characteristic for sending commands later.
                self.commandCharacteristic = characteristic
                print("Found command characteristic.")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        let changedServices = invalidatedServices.map { $0.uuid.uuidString }
        print("Service changed event received. Invalidated services: \(changedServices)")
        peripheral.discoverServices([myService])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
//        let delimiter: UInt8 = 0x04
        
        if characteristic.uuid == dataCharacteristicUUID {
            guard let data = characteristic.value else {
                print("No data received for \(characteristic.uuid.uuidString)")
                return
            }
//            print("received packet \(String(data: data, encoding: .utf8)!)")
//            
//            currPacket.append(data)
//            
//            while let idx = currPacket.firstIndex(of: delimiter) {
//                let packetData = currPacket.subdata(in: 0..<idx)
//                
//                do {
//                    let packet = try JSONDecoder().decode(Packet.self, from: packetData)
//                    
//                    currPacket.removeSubrange(0...idx)
//                    
//                    DispatchQueue.main.async {
//                        self.packets.append(packet)
//                        self.computedMCV = calcMCV(from: packet)
//                    }
//                    print("successfully built packet")
//                } catch {
//                    print("failed to decode json: \(error), \(String(data: currPacket, encoding: .utf8) ?? "no data")")
//                }
//            }
            
            do {
                print("received packet \(String(data: data, encoding: .utf8)!)")
                
                currPacket += String(data: data, encoding: .utf8)!
                
                //add data string to currPacket
                //check if we can decode currPacket:
                    //if yes: add to packets list, display the mcv, clear currPacket
                    //if no: just return and wait for next packet
                
                let packet = try JSONDecoder().decode(Packet.self, from: currPacket.data(using: .utf8)!)
                
                DispatchQueue.main.async {
                    self.currPacket = ""
                    self.packets.append(packet)
                    let mcv = calcMCV(from: packet)
                    self.computedMCV = mcv
                }
                print("successfully built packet")
            } catch {
                print("Failed to decode JSON: \(error), \(currPacket)")
            }
        }
    }
}
