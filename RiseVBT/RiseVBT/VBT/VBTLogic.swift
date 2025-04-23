//
//  VBTLogic.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/14/25.
//

import Foundation
import Charts

func getVelocityPoints(from model: DataModel) -> [LineMark] {
    guard let packets = model.packets else {
        print("empty packets")
        return []
    }
    
    var marks: [LineMark] = []
    
    for packet in packets {
        let v = packet.velocityMs
        let t = packet.timeS
        let mark = LineMark(
            x: .value("Velocity (m/s)", v),
            y: .value("Time (s)", t)
        )
        marks.append(mark)
    }
    
    return marks
}
