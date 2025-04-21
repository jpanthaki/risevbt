//
//  AnalysisView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/19/25.
//

import SwiftUI


struct AnalysisView: View {
    
    var accentColor: Color
    var navbarBackground: Color
    var backgroundColor: Color
    var preferDarkMode: Bool
    
    var model: DataModel
    var onClose: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        //chart here
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lift: \(model.lift.rawValue)")
                            Text("Weight: \(model.weight, format: .number.precision(.fractionLength(1))) \(model.standard.rawValue)")
                            Text("Reps: \(model.reps)")
                            Text("RPE: \(model.rpe, format: .number.precision(.fractionLength(1)))")
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white).shadow(radius: 4))
                        
                        Button ("View Video Footage") {
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
