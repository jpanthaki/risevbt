//
//  Packet.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/14/25.
//

import Foundation

enum RepDirection: String, Codable {
    case ecc
    case con
}

struct MetricData: Codable {
    let timeStamp: Double
    let velocity: Double
    let accel: Double
//    let pitch: Double
//    let yaw: Double
    
    
    enum CodingKeys: String, CodingKey {
        case timeStamp = "time_stamp"
        case velocity
        case accel
//        case pitch
//        case yaw
    }
}

// Structure for the entire packet.
struct Packet: Codable {
    let packetTimeStamp: Double
    let dir: RepDirection
    let data: [MetricData]
    
    
    enum CodingKeys: String, CodingKey {
        case packetTimeStamp = "packet_time_stamp"
        case dir
        case data
    }
}

