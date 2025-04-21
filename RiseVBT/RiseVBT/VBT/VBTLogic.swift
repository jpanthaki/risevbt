//
//  VBTLogic.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/14/25.
//

import Foundation
import Charts

func calcMCV(from packet: Packet) -> Double? {
    guard packet.dir == .con else {
        print("Packet is not from the concentric phase; ignoring data.")
        return nil
    }
    
    let timestamps = packet.data.map { $0.timeStamp }
    let velocities = packet.data.map { $0.velocity }
    
    guard !velocities.isEmpty else {
        print("No velocity data available.")
        return nil
    }
    
    let arithmeticMean = velocities.reduce(0, +) / Double(velocities.count)
    
    guard timestamps.count > 1 else {
        print("Insufficient data points for time-weighted calculation; returning arithmetic mean.")
        return arithmeticMean
    }
    
    var weightedSum = 0.0
    for i in 0..<(timestamps.count - 1) {
        let dt = timestamps[i+1] - timestamps[i]
        weightedSum += velocities[i] * dt
    }
    
    let totalTime = timestamps.last! - timestamps.first!
    let timeWeightedMean = totalTime > 0 ? weightedSum / totalTime : arithmeticMean
    
    return timeWeightedMean
}

func getVelocityPoints(from model: DataModel) -> [LineMark] {
    guard let packets = model.packets else {
        print("empty packets")
        return []
    }
    
    var marks: [LineMark] = []
    let t0: Double = packets[0].data[0].timeStamp
    
    for packet in packets {
        for data in packet.data {
            let v = data.velocity
            let t = data.timeStamp - t0
            let mark = LineMark(
                x: .value("Velocity (m/s)", v),
                y: .value("Time (s)", t)
            )
            marks.append(mark)
        }
    }
    
    return marks
}

func getMCVs(from model: DataModel) -> [Double: Double] {
    var mcvs: [Double: Double] = [:]
    
    guard let packets = model.packets else {
        print("empty packets")
        return mcvs
    }
    
    let t0 = packets[0].data[0].timeStamp
    
    for packet in packets {
        if packet.dir == .con {
            guard let mcv = calcMCV(from: packet) else {
                continue
            }
            let t = packet.data[0].timeStamp - t0
            mcvs[t] = mcv
        }
    }
    
    return mcvs
}
