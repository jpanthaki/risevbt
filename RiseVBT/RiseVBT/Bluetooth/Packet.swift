//
//  Packet.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/14/25.
//

import Foundation

struct Packet: Codable {
    
    let timeMs: UInt16
    let velocity: Int16
    let accel: Int16
    let pitch: Int16
    let yaw: Int16
    
    static let byteSize = 5 * MemoryLayout<Int16>.size
    
    init?(data: Data) {
        guard data.count == Packet.byteSize else {
            return nil
        }
        self.init(from: data, offset: 0)
    }
    
    private init(from data: Data, offset: Int) {
        let base = data.withUnsafeBytes { ptr in ptr.baseAddress!.advanced(by: offset) }
        timeMs = UInt16(littleEndian: base.load(as: UInt16.self))
        velocity = Int16(littleEndian: base.advanced(by: 2).load(as: Int16.self))
        accel = Int16(littleEndian: base.advanced(by: 4).load(as: Int16.self))
        pitch = Int16(littleEndian: base.advanced(by: 6).load(as: Int16.self))
        yaw = Int16(littleEndian: base.advanced(by: 8).load(as: Int16.self))
    }
    
    var timeS: Double { Double(timeMs) / 1000.0 }
    var velocityMs: Double { Double(velocity) / 1000.0 }
    var accelMs2: Double  { Double(accel) / 100.0 }
    var pitchDeg: Double  { Double(pitch) / 100.0 }
    var yawDeg: Double    { Double(yaw) / 100.0 }
}

