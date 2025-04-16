//
//  DataModel.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/15/25.
//

import Foundation
import SwiftData

enum LiftType: String, Codable, CaseIterable, Identifiable {
    case Bench
    case Squat
    case Deadlift
    
    var id: String { self.rawValue }
}

enum WeightStandard: String, Codable, CaseIterable, Identifiable {
    case lbs
    case kgs
    
    var id: String { self.rawValue }
}

@Model
final class DataModel {
    
    var id: UUID = UUID()
    var packet: Packet
    
    var lift: LiftType?
    var weight: Double?
    var standard: WeightStandard?
    
    var reps: Int?
    var ratePerceivedExertion: Int?
    var minVelocityThreshold: Double?
    
    
    init(packet: Packet) {
        self.packet = packet
    }
}
