//
//  HeartRateAnalysis.swift
//  wearable-ios
//
//  Adapted by Luke Redmore on 9/19/24.
//  Includes code adapted from user Jean-Paul 4/26/17 (https://stackoverflow.com/a/43607179/11053269)
//

import Darwin
import Foundation

// This file defines the PPG data structure sequence and adds methods to an array containing them in order to first calculate the

struct PPGDataPoint: Hashable {
    enum Peak {
        case positive, negative, neutral
    }
    
    let timestamp: Date
    let value : UInt32
    
    // Whether or not the data point is in a peak. Only set in the result of Array<PPGDataPoint>.calculatePeaks(), not the raw data
    let peak: Peak?
    
    init(timestamp: Date, value: UInt32, peak: Peak? = nil) {
        self.timestamp = timestamp
        self.value = value
        self.peak = peak
    }
    
    func withPeak(_ peak: Peak) -> Self {
        Self(timestamp: timestamp, value: value, peak: peak)
    }
}

extension Array<PPGDataPoint> {
    
    /**
     Calculate the peaks of the given PPG data. This method returns a **new** array of the same `PPGDataPoint` element, but the `peak` property is now set. Not that it is not guarenteed to be set, since
     providing less than 200 samples will just return `self`.
     - Parameters:
         - lagMean: The number of samples used to calculate the moving average (mean) filter. Must be less than the length of the array.
         - lagStd: The number of samples used to calculate the moving standard deviation filter. Must be less than the length of the array.
         - threshold: The threshold value that determines when a significant deviation from the mean occurs, which triggers the detection of a peak.
         - influenceMean: A factor that controls how much new signal values influence the mean filter.
         - influenceStd: A factor that controls how much new signal values influence the standard deviation filter.

      - Returns: A tuple containing three values:
            1. An array of `PPGDataPoint` elements where the `peak` property is set to either `.positive`, `.negative`, or `.neutral` based on the calculated peaks.
            2. An array of doubles representing the adjusted average filter over time.
            3. An array of doubles representing the adjusted standard deviation filter over time.
    */
    func calculatePeaks(lagMean: Int, lagStd: Int, threshold: Double, influenceMean: Double, influenceStd: Double) -> ([PPGDataPoint], [Double], [Double]) {
        let y = self
        
        // Create arrays
        var signals: [PPGDataPoint] = y
        var filteredYmean = Array<Double>(repeating: 0.0, count: y.count)
        var filteredYstd = Array<Double>(repeating: 0.0, count: y.count)
        var avgFilter = Array<Double>(repeating: 0.0, count: y.count)
        var stdFilter = Array<Double>(repeating: 0.0, count: y.count)
        
        if (signals.count <= lagMean - 1 || signals.count <= lagStd - 1) { return (y, [], []) }
        
        guard Swift.max(lagMean,lagStd) <= y.count - 1 else { return (y, [], []) }

        // Initialise variables
        for i in 0...lagMean-1 {
            let val = Double(y[i].value)
//            signals[i] = 0
            filteredYmean[i] = val
            filteredYstd[i] = val
        }

        // Start filter
        avgFilter[lagMean-1] = y.slice(s: 0, e: lagMean-1).arithmeticMean(for: \.value)
        stdFilter[lagStd-1] = y.slice(s: 0, e: lagStd - 1).standardDeviation(for: \.value)

        for i in Swift.max(lagMean,lagStd)...y.count-1 {
            let val = Double(y[i].value)
            if abs(val - avgFilter[i-1]) > threshold*stdFilter[i-1] {
                if val > avgFilter[i-1] {
                    signals[i] = signals[i].withPeak(.positive)     // Positive signal
                } else {
                    signals[i] = signals[i].withPeak(.negative)       // Negative signal
                }
                filteredYmean[i] = influenceMean*val + (1-influenceMean)*filteredYmean[i-1]
                filteredYstd[i] = influenceStd*val + (1-influenceStd)*filteredYstd[i-1]
            } else {
                signals[i] = signals[i].withPeak(.neutral)          // No signal
                filteredYmean[i] = val
                filteredYstd[i] = val
            }
            // Adjust the filters
            avgFilter[i] = filteredYmean.slice(s: i-lagMean, e: i).arithmeticMean(for: \.self)
            stdFilter[i] = filteredYstd.slice(s: i-lagStd, e: i).standardDeviation(for: \.self)
        }
        return (signals, avgFilter, stdFilter)
    }
    
    
    /// Calculate the heart rate using the timestamps at the end of each peak. Note that this method will ONLY return a usable result if the `peak` property on `PPGDataPoint` has been set
    func calculateHeartRate() -> Double? {
        if (self.count < 2) {
            return nil
        }
        // Step 1: Find the timestamps at the end of each peak
        var peakTimestamps: [Date] = []
        for i in 0..<(self.count - 1) {
            if let peak = self[i].peak, peak == .positive, self[i + 1].peak != .positive {
                peakTimestamps.append(self[i].timestamp)
            }
        }
        
        if (peakTimestamps.count < 2) {
            return nil
        }

        // Step 2: Calculate time intervals between consecutive peaks (in seconds)
        var timeIntervals: [TimeInterval] = []
        for i in 1..<peakTimestamps.count {
            let interval = peakTimestamps[i].timeIntervalSince(peakTimestamps[i - 1])
            timeIntervals.append(interval)
        }

        // Step 3: Calculate the average time interval (in seconds)
        let averageInterval = timeIntervals.reduce(0, +) / Double(timeIntervals.count)

        // Step 4: Calculate heart rate (beats per minute)
        let heartRate = 60.0 / averageInterval
        
        return heartRate
    }
}
