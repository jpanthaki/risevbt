//
//  DataVisualization.swift
//  TestAnalysisView
//
//  Created by Jamshed Panthaki on 4/28/25.
//

import SwiftUI
import Charts
import Combine
import AVKit

enum Page {
    case media
    case info
}

class DataPlaybackViewModel: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var isPlaying = false
    @Published var pageSelection: Page = .media
    
    let model: DataModel
    let packets: [Packet]
    let dataPoints: [DataPoint]
    let duration: Double
    private var timerCancellable: AnyCancellable?
    private let step: Double = 0.02
    
    private var wasPlaying = false
    
    init(model: DataModel) {
        self.model = model
        if let packets = model.packets {
            self.packets = packets.sorted { $0.timeS < $1.timeS }
        } else {
            self.packets = []
        }
        self.duration = self.packets.last?.timeS ?? 0
        self.dataPoints = self.packets.map {
            DataPoint(time: $0.timeS, velocity: $0.velocityMs)
        }
    }
    
    var currentPitchAngle: Double {
        guard let pkt = packets.last(where: { $0.timeS <= currentTime }) else { return 0 }
        return pkt.pitchDeg
    }
    
    var currentYawAngle: Double {
        guard let pkt = packets.last(where: { $0.timeS <= currentTime }) else { return 0 }
        return pkt.yawDeg
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
        currentTime = 0
    }
    
    func togglePlayPause() {
        isPlaying ? pause() : play()
    }
    
    func pageChanged(to newPage: Page) {
        switch newPage {
        case .media:
            if wasPlaying {
                self.play()
                wasPlaying = false
            }
        case .info:
            wasPlaying = isPlaying
            if wasPlaying {
                self.pause()
            }
        }
    }
}

struct BarbellBalance: View {
    let angle: Double
    let accentColor: Color
    
    var body: some View {
        HStack {
            Text("L")
                .font(.headline)
            
            ZStack {
                //bar
                Capsule()
                    .fill(accentColor)
                    .frame(width: 200, height: 6)
                
                //plates
                HStack {
                    HStack(spacing: 2){
                        Rectangle()
                            .fill(accentColor)
                            .frame(width: 12, height: 50)
                            .cornerRadius(4)
                        Rectangle()
                            .fill(accentColor)
                            .frame(width: 12, height: 50)
                            .cornerRadius(4)
                        Rectangle()
                            .fill(accentColor)
                            .frame(width: 12, height: 50)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    HStack(spacing: 2){
                        Rectangle()
                            .fill(accentColor)
                            .frame(width: 12, height: 50)
                            .cornerRadius(4)
                        Rectangle()
                            .fill(accentColor)
                            .frame(width: 12, height: 50)
                            .cornerRadius(4)
                        Rectangle()
                            .fill(accentColor)
                            .frame(width: 12, height: 50)
                            .cornerRadius(4)
                    }
                }
                .frame(width: 200)
            }
            .rotationEffect(.degrees(angle), anchor: .center)
            .animation(.easeInOut(duration: 0.1), value: angle)
            .shadow(radius: 2)
            
            Text("R")
                .font(.headline)
        }
        .padding()
    }
}

struct VelocityChart: View {
    @ObservedObject var vm: DataPlaybackViewModel
    let accentColor: Color
    
    var body: some View {
        Chart {
            ForEach(vm.dataPoints) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Velocity", point.velocity)
                )
                .foregroundStyle(
                    by: .value("Phase", point.time <= vm.currentTime ? "Played" : "Pending")
                )
                .interpolationMethod(.cardinal)
            }
            if let head = vm.dataPoints.last(where: { $0.time <= vm.currentTime }) {
                PointMark(
                    x: .value("Time", head.time),
                    y: .value("Velocity", head.velocity)
                )
                .symbolSize(100)
                .foregroundStyle(accentColor)
                .annotation(position: head.time < vm.duration/2 ? .trailing : .leading) {
                    Text(String(format: "%.2f m/s", head.velocity))
                        .font(.caption2)
                        .padding(4)
                }
            }
        }
        .chartXScale(domain: 0...vm.duration)
        .chartForegroundStyleScale([
            "Played": accentColor,
            "Pending": accentColor.opacity(0.2)
        ])
        .chartLegend(.hidden)
        .frame(height: 100)
        .padding()
    }
}

struct PlaybackControls: View {
    @ObservedObject var vm: DataPlaybackViewModel
    
    var body: some View {
        VStack {
            HStack {
                Text(String(format: "%.2f s", vm.currentTime))
                    .font(.caption)
                Slider(value: $vm.currentTime, in: 0...vm.duration) { editing in
                    if editing {
                        vm.pause()
                    } else if vm.isPlaying {
                        vm.play()
                    }
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 40) {
                Button {
                    vm.reset()
                } label: {
                    Image(systemName: "gobackward")
                }
                Button {
                    vm.togglePlayPause()
                } label: {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                }
            }
            .font(.title)
            .padding()
        }
    }
}

struct DataModelSummary: View {
    let model: DataModel
    
    var body: some View {
        List {
            Section(header: Text("Session Info")) {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(model.createdAt, style: .date)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Lift")
                    Spacer()
                    Text(model.lift.rawValue.capitalized)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Weight")
                    Spacer()
                    Text(String(format: "%.1f %@", model.weight,
                                model.standard.rawValue))
                    .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Reps")
                    Spacer()
                    Text("\(model.reps)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("RPE")
                    Spacer()
                    Text(String(format: "%.1f", model.rpe))
                        .foregroundColor(.secondary)
                }
            }
        }
        .scrollDisabled(true)
    }
}

struct DataVisualization: View {
    
    @StateObject private var vm: DataPlaybackViewModel
    let accentColor: Color
    
    init(model: DataModel, accentColor: Color) {
        _vm = StateObject(wrappedValue: DataPlaybackViewModel(model: model))
        self.accentColor = accentColor
    }
    
    var body: some View {
        TabView(selection: $vm.pageSelection) {
            VStack {
                BarbellBalance(angle: vm.currentPitchAngle, accentColor: accentColor)
                    .frame(height: 100)
                
                VelocityChart(vm: vm, accentColor: accentColor)
                
                PlaybackControls(vm: vm)
            }
            .padding()
            .tag(Page.media)
            
            DataModelSummary(model: vm.model)
                .tag(Page.info)
                .padding()
            
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .onChange(of: vm.pageSelection) {
            vm.pageChanged(to: vm.pageSelection)
        }
    }
}

struct DataVisualizationWithVideo: View {
    @StateObject private var vm: DataPlaybackViewModel
    let accentColor: Color
    let videoURL: URL
    
    @State private var player = AVPlayer()
    
    init(model: DataModel, accentColor: Color, videoURL: URL) {
        _vm = StateObject(wrappedValue: DataPlaybackViewModel(model: model))
        self.accentColor = accentColor
        self.videoURL = videoURL
    }
    
    var body: some View {
        
        TabView(selection: $vm.pageSelection) {
            VStack {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, minHeight: 350)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                    VideoPlayer(player: player)
                        .frame(minHeight: 350)
                        .onAppear {
                            let item = AVPlayerItem(url: videoURL)
                            player.replaceCurrentItem(with: item)
                            player.pause()
                            player.seek(to: .zero)
                        }
                        .onChange(of: vm.isPlaying) {
                            if vm.isPlaying {
                                player.play()
                            } else {
                                player.pause()
                            }
                        }
                        .onChange(of: vm.currentTime) {
                            let cm = CMTime(seconds: vm.currentTime, preferredTimescale: 600)
                            player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
                        }
                        .padding()
                }
                
                BarbellBalance(angle: vm.currentPitchAngle, accentColor: accentColor)
                    .frame(height: 100)
                
                VelocityChart(vm: vm, accentColor: accentColor)
                
                PlaybackControls(vm: vm)
            }
            .tag(Page.media)
            
            DataModelSummary(model: vm.model)
                .tag(Page.info)
                .padding()
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .onChange(of: vm.pageSelection) {
            vm.pageChanged(to: vm.pageSelection)
        }
    }
}




