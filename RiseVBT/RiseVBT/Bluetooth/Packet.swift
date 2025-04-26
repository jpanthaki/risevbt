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
    
    static let byteSize = MemoryLayout<UInt16>.size + 4 * MemoryLayout<Int16>.size
    
    init?(data: Data) {
        guard data.count == Packet.byteSize else {
            return nil
        }
        self.init(from: data, offset: 0)
    }
    
    private init(from data: Data, offset: Int) {
        timeMs = data.withUnsafeBytes{ ptr in
            let base = ptr.baseAddress!.advanced(by: offset)
            return UInt16(littleEndian: base.assumingMemoryBound(to: UInt16.self).pointee)
        }
        
        let base = data.withUnsafeBytes { ptr in ptr.baseAddress!.advanced(by: offset + 4) }
        velocity = Int16(littleEndian: base.assumingMemoryBound(to: Int16.self).pointee)
        accel    = Int16(littleEndian: base.advanced(by: 2).assumingMemoryBound(to: Int16.self).pointee)
        pitch    = Int16(littleEndian: base.advanced(by: 4).assumingMemoryBound(to: Int16.self).pointee)
        yaw      = Int16(littleEndian: base.advanced(by: 6).assumingMemoryBound(to: Int16.self).pointee)
    }
    
    var timeS: Double { Double(timeMs) / 1000.0 }
    var velocityMs: Double { Double(velocity) / 1000.0 }
    var accelMs2: Double  { Double(accel) / 100.0 }
    var pitchDeg: Double  { Double(pitch) / 100.0 }
    var yawDeg: Double    { Double(yaw) / 100.0 }
}

