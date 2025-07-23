//
//  HeartRateView.swift
//  wearable-ios
//
//  Created by Luke Redmore on 9/18/24.
//

import SwiftUI
import Charts

/// Calculate heart rate across 4 ppg channels and average/display the result. This view and its children tend to run a little slow,
/// so each view is kept very small so as to allow SwiftUI to better handle its performance and to make debugging easier
struct HeartRateView: View {
    @EnvironmentObject var bleModel: BLEModel
    @StateObject var viewModel: HeartRateViewModel
    
    var body: some View {
        List {
            Section {
                DisplayHeartRate(bpm: Int(viewModel.avgHeartRate?.rounded()))
                    .listRowBackground(Color.clear)
            }
            HeartRateChartView(heartRates: viewModel.heartRates)
            HeartRateChannelSelectorView(viewModel: viewModel)
        }
        .navigationTitle("Heart Rate")
        .toolbar {
            if !viewModel.heartRates.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: viewModel.resetHeartRates) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
        }
    }
}
//#Preview {
//    NavigationStack {
//        HeartRateView(id: "mockDeviceId")
//    }
//    .onAppear(perform: HeartRateTestingUtils.publishMockHeartRate)
//}
