//
//  AnalysisView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/15/25.
//

import SwiftUI

struct AnalysisView: View {
    
    @State private var username: String = ""
    @State private var lift: LiftType = .Squat
    @State private var standard: WeightStandard = .lbs
    @State private var weight: Double?
    @State private var reps: Int?
    @State private var rpe: Double?
    
    var body: some View {
        ZStack {
            Color.blue.opacity(0.5)
                .ignoresSafeArea()
            VStack {
                Text("Input Lift Data")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.blue.opacity(0.4))
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.4))
                        HStack {
                            Text("Lift:")
                            Picker("Select lift", selection: $lift) {
                                ForEach(LiftType.allCases) { lift in
                                    Text(lift.rawValue).tag(lift)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding()
                    }
                    .padding()
                }
                .padding(.bottom, 10)
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.blue.opacity(0.4))
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.4))
                        HStack {
                            Text("Weight:")
                            TextField("", text: $username)
                                .textFieldStyle(CustomTextFieldStyle())
                                .disableAutocorrection(true)
                            Picker("Select standard", selection: $standard) {
                                ForEach(WeightStandard.allCases) { standard in
                                    Text(standard.rawValue).tag(standard)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding()
                    }
                    .padding()
                }
                .padding(.bottom, 10)
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.blue.opacity(0.4))
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.4))
                        HStack {
                            Text("Rep Count:")
                            TextField("", text: $username)
                                .textFieldStyle(CustomTextFieldStyle())
                                .disableAutocorrection(true)
                        }
                        .padding()
                    }
                    .padding()
                }
                .padding(.bottom, 10)
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.blue.opacity(0.4))
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.4))
                        HStack {
                            Text("RPE:")
                            TextField("", text: $username)
                                .textFieldStyle(CustomTextFieldStyle())
                                .disableAutocorrection(true)
                        }
                        .padding()
                    }
                    .padding()
                }
                .padding(.bottom, 100)
            }
            .padding()
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray, lineWidth: 1)
            )
    }
}

#Preview {
    AnalysisView()
}
