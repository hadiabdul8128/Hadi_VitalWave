//
//  LivePPGData.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/3/24.
//

import SwiftUI

@MainActor
/// Aggregate data from a single PPG channel into a heart rate
class LivePPGData: ObservableObject {
    let title: String
    
    init(_ title: String, enabled: Bool = false) {
        self.enabled = enabled
        self.title = title
    }
    
    // MARK: Computed properties
    // These variables are Published in the ObservableObject, but are *not* allowed to be changed downstream
    
    /// Every collected PPG data point (except those that fall outside of `outlierThreshold`), but INCLUDING those filtered out by IQR.
    /// This is private because all interaction with the ppg values should be done through `peaks`. The `.peak` property of these elements is NOT set
    @Published var ppgValuesUnfiltered: [PPGDataPoint] = []
    
    /// The collected PPG values with the `.peak` property SET. If `runIQR == true`, then those outliers are filtered out. `outlierThreshold` outliers
    /// are always filtered out. This variable is how one should access ppg values or peak information downstream
    @Published var peaks: [PPGDataPoint] = []
    
    /// Max ppg val of `peaks`
    @Published var ppgMax: UInt32? = nil
    
    /// Min ppg val of `peaks`
    @Published var ppgMin: UInt32? = nil
    
    /// Average ppg val of `peaks`
    @Published var ppgAverage: Float? = nil
    
    /// Heart rate calculated from `peaks`
    @Published var heartRate: Double? = nil
    
    func calculateHeartRate(newData: PPGDataPoint?, forcePPGFilter: Bool = false) async { fatalError("Not implemented!") }
    
    // MARK: Caller API (PPG Data)
    /// These properties and methods can be called/set as Bindings by SwiftUI consumers of this class
    /// Most of these properties rerun `calculateHeartRate` (with no new data) each `didSet` so as to recompute the peaks
    
    /// If false, new ppg values are ignored
    @Published var enabled: Bool
    
    /// How long to hold raw ppg data before discarding it
    @Published var lookbackSeconds: TimeInterval = 15 {
        didSet {
            Task.detached(priority: .userInitiated) {
                await self.calculateHeartRate(newData: nil, forcePPGFilter: true)
            }
        }
    }
    
    /// Clear ppgValues and related stats
    func clearPPG() {
        /*int("[RACE DEBUG] Clearing PPG data with \(peaks.count) total values and \(ppgValuesUnfiltered.count) unfiltered")*/
        ppgMax = nil
        ppgMin = nil
        ppgAverage = nil
        ppgValuesUnfiltered = []
        peaks = []
        heartRate = nil
    }
}
