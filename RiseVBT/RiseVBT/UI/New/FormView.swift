//
//  FormView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/19/25.
//

import SwiftUI

struct FormView: View {
    var accentColor: Color
    var navbarBackground: Color
    var backgroundColor: Color
    var preferDarkMode: Bool
    
    @State var packets: [Packet]?
    @State var mcvValues: [Double]?
    @State var videoURL: URL?
    
    @State private var selectedLift: LiftType = .Bench
    @State private var weight: Double = 0.0
    @State private var selectedStandard: WeightStandard = .lb
    @State private var reps: Int = 1
    @State private var rpe: Double = 6.0
    
    var onSave: (DataModel) -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                
                Form {
                    // Lift section
                    Section("Lift Details") {
                        Picker("Lift Type", selection: $selectedLift) {
                            ForEach(LiftType.allCases) { lift in
                                Text(lift.rawValue).tag(lift)
                            }
                        }
                        HStack {
                            Text("Weight")
                            Spacer()
                            TextField("0.0", value: $weight, format: .number.precision(.fractionLength(1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Picker("Standard", selection: $selectedStandard) {
                            ForEach(WeightStandard.allCases) { std in
                                Text(std.rawValue.uppercased()).tag(std)
                            }
                        }
                    }
                    
                    // Reps & RPE section
                    Section("Reps & RPE") {
                        Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                        HStack {
                            Text("RPE")
                            Slider(value: $rpe, in: 1...10, step: 0.5)
                            Text(rpe, format: .number.precision(.fractionLength(1)))
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                    
                    // Media section
                    Section("Media") {
                        HStack {
                            Text("Video")
                            Spacer()
                            Text(videoURL?.lastPathComponent ?? "None")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Save section
                    Section {
                        Button("Save") {
                            let model = DataModel(
                                packets: packets,
                                mcvValues: mcvValues,
                                lift: selectedLift,
                                weight: weight,
                                standard: selectedStandard,
                                reps: reps,
                                rpe: rpe,
                                videoURL: videoURL
                            )
                            onSave(model)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .tint(accentColor)
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("New Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(navbarBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            onCancel()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            let model = DataModel(
                                packets: packets,
                                mcvValues: mcvValues,
                                lift: selectedLift,
                                weight: weight,
                                standard: selectedStandard,
                                reps: reps,
                                rpe: rpe,
                                videoURL: videoURL
                            )
                            onSave(model)
                        }
                        .tint(accentColor)
                    }
                }
                .tint(accentColor)
            }
        }
        .preferredColorScheme(preferDarkMode ? .dark : .light)
    }
}

#Preview {
    FormView(accentColor: .orange, navbarBackground: .blue.opacity(0.5), backgroundColor: Color(UIColor.systemGroupedBackground), preferDarkMode: false, onSave: {model in print(model)}, onCancel: {})
}
