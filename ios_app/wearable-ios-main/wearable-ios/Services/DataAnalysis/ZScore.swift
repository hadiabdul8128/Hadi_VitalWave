//
//  ZScore.swift
//  wearable-ios
//
//  Created by Luke Redmore on 11/7/24.
//

import Foundation

class ZScore: LivePPGData {
    
    /// Called each time a valid ppg sample is received from the device, updating ppgValues and its statistics (range, mean) if `enabled` is true
    override func calculateHeartRate(newData: PPGDataPoint?, forcePPGFilter: Bool = false) async {
        if !forcePPGFilter, newData == nil, enabled { return } // Should only recompute if no new data when paused
        
        // Temp vars to hold stateful variables in background before updating them all at once
        var newPPGStats: (filteredValues: [PPGDataPoint], ppgMax: UInt32?, ppgMin: UInt32?, ppgAverage: Float?) = (
            self.peaks, self.ppgMax, self.ppgMin, self.ppgAverage
        )
        var newUnfilteredPPGValues = self.ppgValuesUnfiltered
        
        // Append, analyze, and filter ppg data if new data is provided, or if `forcePPGFilter` is enabled
        if let newData {
            if let last = ppgValuesUnfiltered.last, newData.timestamp < last.timestamp {
                print("[HeartRate] Timestamp is earlier than last sample")
            }
            
            // Drop if outlier if enabled, and if it hasn't been too long since the most recent accepted value
            if let last = peaks.last, abs(Int(last.value) - Int(newData.value)) > Int(outlierThreshold), Date.now.distance(to: last.timestamp) < 2.0 {
                print("[HeartRate] Outlier detected: \(last.value) -> \(newData.value)")
            } else {
                newUnfilteredPPGValues = ppgValuesUnfiltered
                newUnfilteredPPGValues.append(newData)
                newPPGStats = analyzeAndFilterPPG(ppg: newUnfilteredPPGValues)
            }
        } else if forcePPGFilter {
            newPPGStats = analyzeAndFilterPPG(ppg: newUnfilteredPPGValues)
        }
        
        // Recalulate peaks/heart rate
        let (peaks, _, _) = newPPGStats.filteredValues.calculatePeaks(lagMean: Int(lagMean), lagStd: Int(lagStd), threshold: threshold, influenceMean: influenceMean, influenceStd: influenceStd)
        let hr = newPPGStats.filteredValues.count > 200 && newPPGStats.ppgAverage != nil && newPPGStats.ppgAverage! > 5000 ? peaks.calculateHeartRate() : nil
        
        // Update state on main thread
        DispatchQueue.main.async { [newPPGStats, newUnfilteredPPGValues] in
            self.ppgMax = newPPGStats.ppgMax
            self.ppgMin = newPPGStats.ppgMin
            self.ppgAverage = newPPGStats.ppgAverage
            self.ppgValuesUnfiltered = newUnfilteredPPGValues
            self.peaks = peaks
            self.heartRate = hr
        }
    }
    
    /// Calculate range, mean, and perform IQR filtering if enabled of PPG data. Does NOT update state. Only called by `analyzeAndFilterPPG`
    private func analyzeAndFilterPPG(ppg: [PPGDataPoint]) -> (filteredValues: [PPGDataPoint], ppgMax: UInt32?, ppgMin: UInt32?, ppgAverage: Float?) {
        let oldestDateToRetain = ppg[ppg.count - 1].timestamp.addingTimeInterval(-1 * lookbackSeconds)
        var newMax: UInt32?
        var newMin: UInt32?
        var ppgSum: UInt32 = 0
        
        var upperBound: Double? = nil
        var lowerBound: Double? = nil
        if runIQR, ppg.count > 5 {
            let sorted = ppg.sorted { $0.value < $1.value }
            let q1 = sorted.percentile(25.0, for: \.value)
            let q3 = sorted.percentile(75.0, for: \.value)
            let iqr = q3 - q1
            lowerBound = q1 - 1.5 * iqr
            upperBound = q3 + 1.5 * iqr
            print("[HeartRate] IQR bounds: (\(lowerBound!), \(upperBound!))")
        }
        
        let newArr = ppg.filter { dataPoint in
            guard dataPoint.timestamp > oldestDateToRetain else { return false }
            if let lowerBound, Double(dataPoint.value) < lowerBound { return false }
            if let upperBound, Double(dataPoint.value) > upperBound { return false }
            
            ppgSum += dataPoint.value
            if (newMax == nil || dataPoint.value > newMax!) { newMax = dataPoint.value }
            if (newMin == nil || dataPoint.value < newMin!) { newMin = dataPoint.value }
            return true
        }.sorted { $0.timestamp < $1.timestamp }
        let ppgAverage = Float(ppgSum) / Float(peaks.count)
        
        return (newArr, newMax, newMin, ppgAverage)
    }
    
    /// New ppg value's who absolute difference with the most recent ppg value exceeds this value will be dropped
    @Published var outlierThreshold: Double = 8000
    
    /// Whether or not to run 25-75 interquartile range filtering on ppgData
    @Published var runIQR = false {
        didSet {
            Task.detached(priority: .userInitiated) {
                await self.calculateHeartRate(newData: nil, forcePPGFilter: true)
            }
        }
    }
    
    // MARK: Caller API (Peak Detection)
    
    /// The number of samples used to calculate the moving average (mean) filter for peak detection
    @Published var lagMean: Double = 17 {
        didSet {
            Task.detached(priority: .userInitiated) {
                await self.calculateHeartRate(newData: nil)
            }
        }
    }
    
    /// The number of samples used to calculate the moving standard deviation filter for peak detection
    @Published var lagStd: Double = 1 // og = 100
    {
        didSet {
            Task.detached(priority: .userInitiated) {
                await self.calculateHeartRate(newData: nil)
            }
        }
    }
    
    /// The threshold value that determines when a significant deviation from the mean occurs, which triggers the detection of a peak.
    @Published var threshold: Double = 2.25 // og = 2
    {
        didSet {
            Task.detached(priority: .userInitiated) {
                await self.calculateHeartRate(newData: nil)
            }
        }
    }
    
    /// Factor that controls how much new signal values influence the mean filter.
    @Published var influenceMean: Double = 1.5
    {
        didSet {
            Task.detached(priority: .userInitiated) {
                await self.calculateHeartRate(newData: nil)
            }
        }
    }
    
    /// Factor that controls how much new signal values influence the standard deviation filter.
    @Published var influenceStd: Double = 0.1
    {
        didSet {
            Task.detached(priority: .userInitiated) {
                await self.calculateHeartRate(newData: nil)
            }
        }
    }
}
