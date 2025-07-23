//
//  Esgalhado.swift
//  wearable-ios
//
//  Created by Luke Redmore on 11/7/24.
//

import Foundation

class Esgalhado: LivePPGData {
    
    // Bandpass filter parameters
    @Published var lowerFrequency: Double = 0.0
    @Published var upperFrequency: Double = 0.0
    @Published var sampleRate: Double = 0.0
    
    // Initialize with filter settings
//    init(_ title: String, enabled: Bool /*, lowerFrequency: Double, upperFrequency: Double, sampleRate: Double */) {
//        super.init(title, enabled: enabled)
//        self.lowerFrequency = lowerFrequency
//        self.upperFrequency = upperFrequency
//        self.sampleRate = sampleRate
//    }
    
    private func bandpassFilter(signal: [Double]) -> [Double] {
        return signal
//        let filter = BandpassFilter(lowCutoff: lowerFrequency, highCutoff: upperFrequency, sampleRate: sampleRate)
//        return filter.apply(to: signal)
    }
    
    private func hilbertEnvelope(signal: [Double]) -> [Double] {
        return signal
//        let analyticSignal = signal.enumerated().map { (i, _) -> Double in
//            let hilbert = hilbertTransform(signal)
//            return sqrt(pow(signal[i], 2) + pow(hilbert[i], 2))
//        }
//        return analyticSignal
    }
    
    private func trimSignal(upperEnvelope: [Double], lowerEnvelope: [Double]) -> [Double?] {
        return upperEnvelope.enumerated().map { (i, value) -> Double? in
            return value > lowerEnvelope[i] ? value : nil
        }
    }
    
    private func detectPeaks(signal: [Double?], originalData: [PPGDataPoint]) -> [PPGDataPoint] {
        var peaks: [PPGDataPoint] = []
        var currentPeak: (index: Int, value: Double)? = nil
        
        for (i, value) in signal.enumerated() {
            if let v = value {
                if currentPeak == nil || v > currentPeak!.value {
                    currentPeak = (index: i, value: v)
                }
            } else if let peak = currentPeak {
                let peakPoint = originalData[peak.index]
                peaks.append(PPGDataPoint(timestamp: peakPoint.timestamp, value: peakPoint.value, peak: .positive))
                currentPeak = nil
            }
        }
        
        return peaks
    }
    
    func processPPGSignal(ppgData: [PPGDataPoint]) -> [PPGDataPoint] {
        let signal = ppgData.map { Double($0.value) }
        let filteredSignal = bandpassFilter(signal: signal)
        let upperEnvelope = hilbertEnvelope(signal: filteredSignal)
        let lowerEnvelope = hilbertEnvelope(signal: upperEnvelope)
        let trimmedSignal = trimSignal(upperEnvelope: upperEnvelope, lowerEnvelope: lowerEnvelope)
        let peakPoints = detectPeaks(signal: trimmedSignal, originalData: ppgData)
        
        return ppgData.map { point in
            if let matchedPeak = peakPoints.first(where: { $0.timestamp == point.timestamp }) {
                return matchedPeak
            } else {
                return PPGDataPoint(timestamp: point.timestamp, value: point.value, peak: .neutral)
            }
        }
    }
    
    override func calculateHeartRate(newData: PPGDataPoint?, forcePPGFilter: Bool = false) async {
        if !forcePPGFilter, newData == nil, enabled { return } // Should only recompute if no new data when paused
        
        var newUnfilteredPPGValues = self.ppgValuesUnfiltered
        if let newData {
            newUnfilteredPPGValues.append(newData)
        }
        
        let signal = newUnfilteredPPGValues.map { Double($0.value) }
        let filteredSignal = bandpassFilter(signal: signal)
        let upperEnvelope = hilbertEnvelope(signal: filteredSignal)
        let lowerEnvelope = hilbertEnvelope(signal: upperEnvelope)
        let trimmedSignal = trimSignal(upperEnvelope: upperEnvelope, lowerEnvelope: lowerEnvelope)
        let peaks = detectPeaks(signal: trimmedSignal, originalData: newUnfilteredPPGValues)
        let hr = peaks.count > 200 /*&& newPPGStats.ppgAverage != nil && newPPGStats.ppgAverage! > 5000*/ ? peaks.calculateHeartRate() : nil
        
        // Update state on main thread
        DispatchQueue.main.async { [peaks, hr] in
            self.ppgMax = nil
            self.ppgMin = nil
            self.ppgAverage = nil
            self.ppgValuesUnfiltered = newUnfilteredPPGValues
            self.peaks = peaks
            self.heartRate = hr
        }
    }
    
    //    // Process the PPG signal
    //    func processPPGSignal(ppgSignal: [Double]) -> [Int] {
    //        // Step 1: Apply bandpass filter
    //        let filteredSignal = bandpassFilter(signal: ppgSignal)
    //
    //        // Step 2: Calculate the upper envelope
    //        let upperEnvelope = hilbertEnvelope(signal: filteredSignal)
    //
    //        // Step 3: Calculate the lower envelope of the upper envelope
    //        let lowerEnvelope = hilbertEnvelope(signal: upperEnvelope)
    //        
    //        // Step 4: Trim the signal based on the lower envelope
    //        let trimmedSignal = trimSignal(upperEnvelope: upperEnvelope, lowerEnvelope: lowerEnvelope)
    //
    //        // Step 5: Detect peaks in trimmed signal
    //        let peakLocations = detectPeaks(signal: trimmedSignal)
    //
    //        return peakLocations
    //    }
}

