//
//  PPGChartView.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/12/24.
//

import Charts
import SwiftUI

/// Chart of ppg data, with peaks additionally annotated if available
struct PPGChartView: View {
    let peaks: [PPGDataPoint]
    let ppgMin: UInt32?
    let ppgMax: UInt32?
    
    /// Partitions the peaks into subarrays for each group of peaks to display them in red
    var positivePeakSubArrays: [(Int, [PPGDataPoint])] {
        var result: [(Int, [PPGDataPoint])] = []
        var currentSubArray: [PPGDataPoint] = []
        var count = 1
        for dataPoint in peaks {
            if dataPoint.peak == .positive {
                currentSubArray.append(dataPoint)
            } else if !currentSubArray.isEmpty {
                result.append((count, currentSubArray))
                currentSubArray = []
                count += 1
            }
        }
        
        // Append the last sub-array if it's not empty
        if !currentSubArray.isEmpty {
            result.append((count, currentSubArray))
        }
        
        return result
    }
    
    var body: some View {
        Chart {
            ForEach(peaks, id: \.timestamp) { item in
                LineMark(
                    x: .value("Date", item.timestamp),
                    y: .value("PPG", item.value),
                    series: .value("PPG", 0)
                )
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(.blue)
            }
            ForEach(positivePeakSubArrays, id: \.0) { (i, subArray) in
                ForEach(subArray, id: \.timestamp) { item in
                    LineMark(
                        x: .value("Date", item.timestamp),
                        y: .value("Peak-\(i)", item.value),
                        series: .value("Peak-\(i)", i)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.red)
                }
//                if let lastPoint = subArray.last {
//                    PointMark(
//                        x: .value("Date", lastPoint.timestamp),
//                        y: .value("Peak-\(i)", lastPoint.value)
//                    )
//                    .foregroundStyle(.red)
//                }
            }
            
        }
        .if(ppgMin != nil && ppgMax != nil) {
            $0.chartYScale(domain: [ppgMin!, ppgMax!])
        }
        .frame(height: (200))
    }
}

//#Preview {
//    @Previewable @StateObject var model = HeartRateViewModel(id: "mockDeviceId")
//    PPGChartView(peaks: model.ppg_r.peaks, ppgMin: model.ppg_r.ppgMin, ppgMax: model.ppg_b.ppgMax)
//        .onAppear(perform: HeartRateTestingUtils.publishMockHeartRate)
//}
