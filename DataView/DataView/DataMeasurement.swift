//
//  DataMeasurement.swift
//  DataView
//
//  Created by Jamshed Panthaki on 3/10/25.
//

import Foundation

struct DataMeasurement: Identifiable {
    var id = UUID()
    var time: Double
    var velocity: Double
    
    // just velocity for now
}
