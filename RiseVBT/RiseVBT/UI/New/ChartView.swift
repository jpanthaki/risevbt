//
//  ChartView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/27/25.
//

import SwiftUI
import Charts
import Combine

class ChartViewModel: ObservableObject {
    @Published var currentTime: Double = 0.0
    @Published var isPlaying = false
    
    private var timerCancellable: AnyCancellable?
    let data: [DataPoint]
    let duration: Double
    let step: Double = 0.02
    
    init(data: [DataPoint]) {
        self.data = data.sorted {$0.time < $1.time}
        self.duration = data.map(\.time).max() ?? 0.0
    }
    
    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        timerCancellable = Timer.publish(every: step, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.currentTime >= self.duration {
                    self.pause()
                } else {
                    self.currentTime += self.step
                }
            }
    }
    
    func pause() {
        isPlaying = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    func reset() {
        pause()
        currentTime = 0.0
    }
}

struct ChartView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    ChartView()
}
