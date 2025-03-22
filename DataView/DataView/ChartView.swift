//
//  ChartView.swift
//  DataView
//
//  Created by Jamshed Panthaki on 3/10/25.
//

import SwiftUI
import Charts

struct ChartView: View {
    var dataCollection: DataViewModel
    
    var body: some View {
        
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack {
                Text("Velocity vs. Time")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Chart(dataCollection.data) {
                    LineMark(
                        x: .value("Time:", $0.time),
                        y: .value("Velocity:", $0.velocity)
                    )
                    .foregroundStyle(Color.blue)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 5.0)) { value in
                        AxisGridLine() // Add grid lines
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisTick() // Add ticks
                            .foregroundStyle(Color.white)
                        if let time = value.as(Double.self) {
                            AxisValueLabel("\(time, specifier: "%.1f")")
                                .foregroundStyle(Color.white)
                        }
                    }
                    
                }
                .chartYAxis {
                    AxisMarks(values: .stride(by: 1.0)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.3))
                        AxisTick()
                            .foregroundStyle(Color.white)
                        if let v = value.as(Double.self) {
                            AxisValueLabel("\(v, specifier: "%.1f")")
                                .foregroundStyle(Color.white)
                        }
                    }
                }
                .padding()
                .frame(height: 200)
            }
            
        }
        
    }
}

#Preview {
    ChartView(dataCollection: DataViewModel())
}
