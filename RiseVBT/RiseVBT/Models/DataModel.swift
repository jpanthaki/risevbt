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
    case lb
    case kg
    
    var id: String { self.rawValue }
}

@Model
final class DataModel {
    
    var id: UUID = UUID()
    var packets: [Packet]?
    
    var videoURL: URL?
    
    var lift: LiftType
    var weight: Double
    var standard: WeightStandard
    
    var reps: Int
    var rpe: Double
    
    
    init(packets: [Packet]? = nil, lift: LiftType, weight: Double, standard: WeightStandard, reps: Int, rpe: Double, videoURL: URL? = nil) {
        self.packets = packets
        self.lift = lift
        self.weight = weight
        self.standard = standard
        self.reps = reps
        self.rpe = rpe
        
        if videoURL != nil {
            self.videoURL = videoURL
        }
    }
}
