//
//  AnalysisView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/19/25.
//

import SwiftUI
import Charts

struct DataPoint: Identifiable {
    let id = UUID()
    let time: Double
    let velocity: Double
}

struct AnalysisView: View {
    
    var accentColor: Color
    var navbarBackground: Color
    var backgroundColor: Color
    var preferDarkMode: Bool
    
    var model: DataModel
    var onClose: () -> Void
    
    private var dataPoints: [DataPoint] {
        (model.packets ?? []).map { pkt in
            DataPoint(time: pkt.timeS,
                      velocity: pkt.velocityMs)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        //video goes here if it's there
                        
                        //chart here
                        Chart(dataPoints) { p in
                            LineMark(
                                x: .value("Time", p.time),
                                y: .value("Velocity", p.velocity)
                            )
                        }
                        .frame(height: 200)
                        .chartXAxisLabel("Time (s)")
                        .chartYAxisLabel("m/s")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lift: \(model.lift.rawValue)")
                            Text("Weight: \(model.weight, format: .number.precision(.fractionLength(1))) \(model.standard.rawValue)")
                            Text("Reps: \(model.reps)")
                            Text("RPE: \(model.rpe, format: .number.precision(.fractionLength(1)))")
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white).shadow(radius: 4))
                        
                        Button ("View Bar Path Analysis") {
                            //play footage here
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                }
                .navigationTitle("Analysis")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            onClose()
                        }
                    }
                }
                .toolbarBackground(navbarBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .tint(accentColor)
            }
        }
        .preferredColorScheme(preferDarkMode ? .dark : .light)
    }
}

#Preview {
    let dummyPackets: [Packet] = (0..<1000).compactMap { i in
        // 1) Create some sample values
        let timeMs: UInt32 = UInt32(i * 10)             // every 10 ms
        let velocity: Int16  = Int16.random(in: -2000...2000)   // ±2 m/s
        let accel:    Int16  = Int16.random(in: -1000...1000)   // ±10 m/s²
        let pitch:    Int16  = Int16.random(in: -18000...18000) // ±180°
        let yaw:      Int16  = Int16.random(in: -18000...18000) // ±180°
        
        // 2) Pack them into Data in little-endian order
        var d = Data()
        withUnsafeBytes(of: timeMs.littleEndian)  { d.append(contentsOf: $0) }
        withUnsafeBytes(of: velocity.littleEndian) { d.append(contentsOf: $0) }
        withUnsafeBytes(of: accel.littleEndian)    { d.append(contentsOf: $0) }
        withUnsafeBytes(of: pitch.littleEndian)    { d.append(contentsOf: $0) }
        withUnsafeBytes(of: yaw.littleEndian)      { d.append(contentsOf: $0) }
        
        // 3) Initialize Packet from the Data
        return Packet(data: d)
    }
    
    let dummyMCVValues: [Double] = [
        0.32, 0.35, 0.30, 0.28, 0.33,
        0.37, 0.40, 0.38, 0.42, 0.45,
        0.43, 0.47, 0.50, 0.48, 0.52,
        0.55, 0.53, 0.57, 0.60, 0.58
    ]
    
    let dummyModel = DataModel(packets: dummyPackets, mcvValues: dummyMCVValues, lift: .Bench, weight: 100, standard: .lb, reps: 10, rpe: 7, videoURL: nil)
    
    AnalysisView(accentColor: .orange, navbarBackground: .blue.opacity(0.5), backgroundColor: Color(UIColor.systemGroupedBackground), preferDarkMode: false, model: dummyModel, onClose: {})
}
