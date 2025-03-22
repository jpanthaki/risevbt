//
//  DataViewModel.swift
//  DataView
//
//  Created by Jamshed Panthaki on 3/10/25.
//

import Foundation

class DataViewModel {
    var data: [DataMeasurement] = createSquatVelocityData()
}

func createSquatVelocityData() -> [DataMeasurement] {
    var data: [DataMeasurement] = []
    let duration = 30.0 // Total duration of the squat in seconds
    let timeInterval = 0.1 // Time interval between measurements
    
    var time = 0.0
    while time <= duration {
        // Simulate the velocity profile of a squat
        let velocity = simulateSquatVelocity(at: time, duration: duration)
        data.append(DataMeasurement(time: time, velocity: velocity))
        time += timeInterval
    }
    
    return data
}

func simulateSquatVelocity(at time: Double, duration: Double) -> Double {
    // Simulate the velocity profile of a squat
    let midPoint = duration / 2.0
    
    if time < midPoint {
        // Descending phase: velocity increases, then decreases
        return -sin((time / midPoint) * .pi) * 2.0
    } else {
        // Ascending phase: velocity increases, then decreases
        return sin(((time - midPoint) / midPoint) * .pi) * 2.0
    }
}
