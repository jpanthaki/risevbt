//
//  RiseVBTTests.swift
//  RiseVBTTests
//
//  Created by Jamshed Panthaki on 4/21/25.
//

import Testing
import CoreBluetooth
import XCTest
@testable import RiseVBT

/// Unit tests for the Packet initializer
final class PacketInitializerTests: XCTestCase {
    func testPacketInitFromData() {
        // Build a raw 12-byte Packet data blob
        var raw = Data()
        raw.append(UInt16(150).littleEndianData)    // timeMs = 150 ms
        raw.append(Int16(823).littleEndianData)     // velocity = 0.823 m/s
        raw.append(Int16(-350).littleEndianData)    // accel = -3.50 m/s2
        raw.append(Int16(7425).littleEndianData)    // pitch = 74.25°
        raw.append(Int16(-16072).littleEndianData)  // yaw = -160.72°
        
        // Initialize Packet directly
        let packet = Packet(data: raw)
        XCTAssertNotNil(packet, "Packet initializer should succeed for valid data length")
        guard let pkt = packet else { return }
        
        XCTAssertEqual(pkt.timeMs, 150, "timeMs should match the raw value")
        XCTAssertEqual(pkt.velocityMs, 0.823, accuracy: 1e-3, "velocityMs should match scaled value")
        XCTAssertEqual(pkt.accelMs2, -3.50, accuracy: 1e-2, "accelMs2 should match scaled value")
        XCTAssertEqual(pkt.pitchDeg, 74.25, accuracy: 1e-2, "pitchDeg should match scaled value")
        XCTAssertEqual(pkt.yawDeg, -160.72, accuracy: 1e-2, "yawDeg should match scaled value")
    }
}

// Helpers to build little-endian Data from primitives
private extension UInt16 {
    var littleEndianData: Data {
        var le = self.littleEndian
        return Data(bytes: &le, count: MemoryLayout<UInt16>.size)
    }
}

private extension Int16 {
    var littleEndianData: Data {
        var le = self.littleEndian
        return Data(bytes: &le, count: MemoryLayout<Int16>.size)
    }
}
