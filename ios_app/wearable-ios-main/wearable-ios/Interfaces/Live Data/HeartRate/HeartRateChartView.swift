//
//  HeartRateChartView.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/12/24.
//

import SwiftUI
import Charts

/// Display a chart of heart rate data over time
struct HeartRateChartView: View {
    let heartRates: [(Date, Double)]
    var body: some View {
        Group {
            if heartRates.count > 0 {
                Section("Over Time") {
                    Chart {
                        ForEach(heartRates, id: \.0) { item in
                            LineMark(
                                x: .value("Date", item.0),
                                y: .value("Value", item.1),
                                series: .value("PPG", 0)
                            )
                            .foregroundStyle(.red)
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: (200))
                }
            }
        }
    }
}
