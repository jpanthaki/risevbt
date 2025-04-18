import SwiftUI
import SwiftData
import PhotosUI   // only if you later want to let the user pick/change a video

struct DataModelFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    
    let packets: [Packet]?
    
    @State private var lift: LiftType         = .Bench
    @State private var weight: Double         = 0
    @State private var standard: WeightStandard = .lb
    @State private var reps: Int              = 1
    @State private var rpe: Double            = 1
    @State private var videoURL: URL?
    
    init(packets: [Packet]? = nil, videoURL: URL? = nil) {
        self.packets = packets
        // initialize the @State
        _videoURL = State(initialValue: videoURL)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    Picker("Lift", selection: $lift) {
                        ForEach(LiftType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Picker("Weight Unit", selection: $standard) {
                        ForEach(WeightStandard.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    
                    HStack {
                        Text("Weight (\(standard.rawValue))")
                        TextField("0", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    
                    Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                    
                    VStack(alignment: .leading) {
                        Text("RPE: \(rpe, format: .number.precision(.fractionLength(1)))")
                        Slider(value: $rpe, in: 1...10, step: 0.5)
                    }
                }
                
                if let url = videoURL {
                    Section("Video Attached") {
                        Text(url.lastPathComponent)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Button("Save Lift") {
                        let newEntry = DataModel(
                            packets:   packets ?? nil,
                            lift:     lift,
                            weight:   weight,
                            standard: standard,
                            reps:     reps,
                            rpe:      rpe,
                            videoURL: videoURL
                        )
                        context.insert(newEntry)
                        dismiss()
                    }
                    .disabled(weight <= 0)   // simple validation
                }
            }
            .navigationTitle("New Lift Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DataModelFormView()
}
