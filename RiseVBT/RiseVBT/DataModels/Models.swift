//
//  Models.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/23/25.
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
    @Attribute(.unique) var id: UUID = UUID()
    
    var createdAt: Date = Date()
    
    var packets: [Packet]?
    
    var mcvValues: [Double]?
    
    var videoURL: URL?
    var processedVideoURL: URL?
    
    var lift: LiftType
    var weight: Double
    var standard: WeightStandard
    
    var reps: Int
    var rpe: Double
    
    
    init(packets: [Packet]?, mcvValues: [Double]?, lift: LiftType, weight: Double, standard: WeightStandard, reps: Int, rpe: Double, videoURL: URL?, processedVideoURL: URL?) {
        
        if let pkts = packets {
            self.packets = pkts
        }
        
        if let mcvs = mcvValues {
            self.mcvValues = mcvs
        }
        
        self.lift = lift
        self.weight = weight
        self.standard = standard
        self.reps = reps
        self.rpe = rpe
        
        if let url = videoURL {
            self.videoURL = url
        }
        
        if let url = processedVideoURL {
            self.processedVideoURL = url
        }
    }
}
