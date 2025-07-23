//
//  ConfigureHeartRateView.swift
//  wearable-ios
//
//  Created by Luke Redmore on 9/30/24.
//

import SwiftUI
import Charts

/// Configuration view controlling calculation parameters in `LivePPGData`
struct ConfigureHeartRateView: View {
    @ObservedObject var ppg: ZScore
    
    var sampleRate: Float32 {
        guard ppg.peaks.count > 1,
              let first = ppg.peaks.first?.timestamp,
              let last = ppg.peaks.last?.timestamp else { return 0.0 }
        let delta = first.distance(to: last)
        return Float32(ppg.peaks.count) / Float32(delta)
    }
    
    var body: some View {
        List {
            Section {
                Toggle("Enabled", isOn: $ppg.enabled)
                NumericalRow(
                    label: "Heart Rate",
                    value: ppg.heartRate != nil ? Float32(ppg.heartRate!) : nil,
                    numDecimals: 3,
                    emptyValue: ppg.enabled ? .loading : .text("Disabled")
                )
            }
            
            Section {
                NumericalRow(label: "Sample Count", value: UInt32(ppg.peaks.count), numDecimals: 0)
                NumericalRow(label: "Frequency (Hz)", value: sampleRate, numDecimals: 1)
                NumericalRow(label: "Average Value", value: ppg.ppgAverage, numDecimals: 2)
                PPGChartView(peaks: ppg.peaks, ppgMin: ppg.ppgMin, ppgMax: ppg.ppgMax)
            } header: {
                Text("PPG Data")
            } footer: {
                Text("Heart rate is calculated from the trailing peak-to-peak interval of the PPG signal. On this chart, calculated peaks are highlighted in red")
            }
            Section {
                HStack {
                    Text("Window size: \(String(format: "%.0f", ppg.lookbackSeconds)) sec")
                    Slider(value: $ppg.lookbackSeconds, in: 10...60, step: 1)
                }
                
                if (ppg.peaks.count > 200) {
                    HStack {
                        Text("Lag Mean: \(String(format: "%.0f", ppg.lagMean))")
                        Slider(value: $ppg.lagMean, in: 1...200, step: 1)
                    }
                    HStack {
                        Text("Lag Std: \(String(format: "%.0f", ppg.lagStd))")
                        Slider(value: $ppg.lagStd, in: 1...200, step: 1)
                    }
                    HStack {
                        Text("Threshold: \(String(format: "%.2f", ppg.threshold))")
                        Slider(value: $ppg.threshold, in: 0...10 , step: 0.01)
                    }
                    HStack {
                        Text("Influence Mean: \(String(format: "%.2f", ppg.influenceMean))")
                        Slider(value: $ppg.influenceMean, in: 0...2, step: 0.01)
                    }
                    HStack {
                        Text("Influence Std: \(String(format: "%.2f", ppg.influenceStd))")
                        Slider(value: $ppg.influenceStd, in: 0...2, step: 0.01)
                    }
                }
                HStack {
                    Text("Outlier threshold: \(String(format: "%.0f", ppg.outlierThreshold))")
                    Slider(value: $ppg.outlierThreshold, in: 0...100_000, step: 1)
                }
                Toggle("25-75 IQR Filter", isOn: $ppg.runIQR)
            } header: {
                Text("Calculation Parameters")
            } footer: {
                if ppg.peaks.count <= 200 {
                    Text("Heart rate and additional configuration parameters are only shown when the number of samples exceeds 200")
                }
            }
        }.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    ppg.clearPPG()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    ppg.enabled.toggle()
                } label: {
                    Image(systemName: ppg.enabled ? "pause.circle.fill" : "play.circle.fill")
                }
            }
        }
        .navigationBarTitle(Text(ppg.title), displayMode: .inline)
    }
}

//#Preview {
//    @Previewable @StateObject var model = HeartRateViewModel(id: "mockDeviceId")
//    NavigationStack {
//        ConfigureHeartRateView(ppg: model.ppg_ir)
//    }
//    .onAppear(perform: HeartRateTestingUtils.publishMockHeartRate)
//}
