//
//  HeartRateViewModel.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/12/24.
//

import SwiftUI
import Combine

//extension Publisher {
//    func asyncMap<T>(
//        _ transform: @escaping (Output) async -> T
//    ) -> Publishers.FlatMap<Future<T, Never>, Self> {
//        flatMap { value in
//            Future { promise in
//                Task.detached { [transform, promise] in
//                    let output = await transform(value)
//                    promise(.success(output))
//                }
//            }
//        }
//    }
//}

@MainActor
/// Collect sensor data from notifications, calculate, then aggregate individual heart rate data from `LivePPGData` for each channel into the model used by `HeartRateView`
class HeartRateViewModel: ObservableObject {    
    // PPG data for each channel
    @Published private(set) var ppg_r = ZScore("Red", enabled: true)
//    @Published private(set) var ppg_re = Esgalhado("Red", enabled: true)
    @Published private(set) var ppg_g = ZScore("Green", enabled: true)
    @Published private(set) var ppg_b = ZScore("Blue", enabled: true)
    @Published private(set) var ppg_ir = ZScore("Infrared", enabled: true)
    
    // Aggregated heart rate values
    @Published private(set) var avgHeartRate: Double? = nil
    @Published private(set) var heartRates: [(Date, Double)] = []
    
    let id: String
    private let samplePublisher: AnyPublisher<(String, Date, SampleData), Never>

    init(id: String, samplePublisher: AnyPublisher<(String, Date, SampleData), Never>) {
        self.id = id
        self.samplePublisher = samplePublisher
        startListening()
    }
    
    private var cancellables = Set<AnyCancellable>()
    deinit {
        notificationTask?.cancel()
    }
    
    /// Clear heart rates array and set `avgHeartRate = nil`
    func resetHeartRates() {
        heartRates.removeAll()
        avgHeartRate = nil
    }
    
    
    
    private var notificationTask: Task<Void, Never>?
    /// Listen for internal notifications of new samples, then process them on a background thread
    private func startListening() {
//        self.samplePublisher
//            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
//            .compactMap { [weak self] (deviceId, timestamp, sample) in
//                guard let self = self, self.id == deviceId else { return nil }
//                return (timestamp, sample)
//            }
//            .asyncMap { (timestamp: Date, sample: SampleData) -> (Double?, [(Date, Double)])  in
//                print("received sample!")
//                await self.appendSampleToPPGStream(sample.ppg_ir, to: self.ppg_ir, at: timestamp)
//                await self.appendSampleToPPGStream(sample.ppg_r, to: self.ppg_r, at: timestamp)
//                await self.appendSampleToPPGStream(sample.ppg_g, to: self.ppg_g, at: timestamp)
//                await self.appendSampleToPPGStream(sample.ppg_b, to: self.ppg_b, at: timestamp)
//                let (newHR, newHRates) = await self.calculateAverageHeartRate()
//                return (newHR, newHRates)
////                await MainActor.run { [newHRates, newHR] in
////                    self.heartRates = newHRates
////                    self.avgHeartRate = newHR
////                }
//            }
//            .receive(on: DispatchQueue.main)
//            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] (newHR, newHRates) in
//                guard let self = self else { return }
//                self.heartRates = newHRates
//                self.avgHeartRate = newHR
//            })
//            .store(in: &cancellables)
        
        notificationTask = Task.detached { [weak self] in
            guard let self = self else { return }
            for await (deviceId, timestamp, sample) in self.samplePublisher
//                .buffer(size: Int.max, prefetch: .keepFull, whenFull: .dropOldest)
                .values {
                guard id == deviceId else { continue }
//                if let r = sample.ppg_r {
////                    print("[RACE DEBUG] received sample at \(timestamp.toISOMillisString())")
//                }
//                Task {
                    await self.appendSampleToPPGStream(sample.ppg_ir, to: self.ppg_ir, at: timestamp)
                    await self.appendSampleToPPGStream(sample.ppg_r, to: self.ppg_r, at: timestamp)
                    await self.appendSampleToPPGStream(sample.ppg_g, to: self.ppg_g, at: timestamp)
                    await self.appendSampleToPPGStream(sample.ppg_b, to: self.ppg_b, at: timestamp)
                    let (newHR, newHRates) = await self.calculateAverageHeartRate()
//                    return (newHR, newHRates)
                    await MainActor.run { [newHRates, newHR] in
                        self.heartRates = newHRates
                        self.avgHeartRate = newHR
                    }
                   
                    
//                }
            }
        }
    }
    
    /// Append a new sample to the indicated stream
    private func appendSampleToPPGStream(_ sample: UInt32?, to model: LivePPGData, at timestamp: Date) async {
        if let sample, model.enabled {
            await model.calculateHeartRate(newData: PPGDataPoint(timestamp: timestamp, value: sample))
        }
    }
    
    /// Calculate an average HR across each child, then update the full HR array
    private func calculateAverageHeartRate() async -> (Double?, [(Date, Double)]) {
        // First calculate average heart rate from 4 streams
        func addToHR(_ ppg: LivePPGData) {
            if ppg.enabled, let hr = ppg.heartRate {
                sum += hr
                count += 1
            }
        }
        var sum: Double = 0.0
        var count = 0
        addToHR(ppg_ir)
        addToHR(ppg_r)
        addToHR(ppg_g)
        addToHR(ppg_b)

        let testavg = sum / Double(count)
        let newHR = testavg < 200.0 ? testavg : nil
        
        // Then append it to the heart rate array, as well as filter out old values
        let newest = Date()
        var newHRates = self.heartRates
        while true {
            if let (oldest, _) = newHRates.first, oldest.distance(to: newest) > TimeInterval(15.0) {
                newHRates.removeFirst()
            } else { break }
        }
        if let newHR {
            newHRates.append((newest, newHR))
        }
        
        return (newHR, newHRates)
    }
}
