//
//  HeartRateChannelSelectorView.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/12/24.
//

import SwiftUI

/// List section with 4 rows to select and configure each ppg channel's contribution to the calculated heart rate
struct HeartRateChannelSelectorView: View {
    @ObservedObject var viewModel: HeartRateViewModel
    
    @ViewBuilder
    private func ConfigureHeartRateRow(for ppg: ZScore) -> some View {
        NavigationLink {
            ConfigureHeartRateView(ppg: ppg)
        } label: {
            NumericalRow(
                label: ppg.title,
                value: ppg.enabled ? Float32(ppg.heartRate) : nil,
                numDecimals: 2,
                emptyValue: ppg.enabled ? .loading : .text("Disabled")
            )
        }
    }
    
    var body: some View {
        Section {
            ConfigureHeartRateRow(for: viewModel.ppg_r)
            ConfigureHeartRateRow(for: viewModel.ppg_g)
            ConfigureHeartRateRow(for: viewModel.ppg_b)
            ConfigureHeartRateRow(for: viewModel.ppg_ir)
        } header: {
            Text("Per Channel")
        } footer: {
            if viewModel.avgHeartRate == nil {
                Text("Touch the sensor to calculate heart rate.")
            } else {
                Text("Heart rate is calculated using the average of 4 channels of PPG data. To configure these calculations, tap any row.")
            }
        }
    }
}

//#Preview {
//    @Previewable @StateObject var model = HeartRateViewModel(id: "mockDeviceId")
//    NavigationStack {
//        List {
//            HeartRateChannelSelectorView(viewModel: model)
//        }
//    }
//    .onAppear(perform: HeartRateTestingUtils.publishMockHeartRate)
//}
