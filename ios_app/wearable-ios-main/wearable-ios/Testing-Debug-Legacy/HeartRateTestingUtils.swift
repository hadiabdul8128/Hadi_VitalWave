//
//  HeartRateTestingUtils.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/12/24.
//
import Foundation

struct HeartRateTestingUtils {
    
    /// Creates a timer sending a mock sample received notification with only ppg data at 100Hz
    static func publishMockHeartRate() {
        var time = 0.0
        
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            // Simulate a sine wave with added noise to represent PPG data
            let frequency = 1.5   // Adjust frequency to simulate PPG cycle (about 60-80 bpm)
            let amplitude = 5000.0 // Amplitude of the PPG wave
            let sin = 75000 + amplitude * sin(2 * .pi * frequency * time)
            
            let noise1 = Double.random(in: -500...500) // Add random noise
            let value1 = UInt32(sin + noise1)
            var littleEndianValue1 = value1.littleEndian
            let data1 = Data(bytes: &littleEndianValue1, count: MemoryLayout.size(ofValue: littleEndianValue1))
            
            let noise2 = Double.random(in: -500...500) // Add random noise
            let value2 = UInt32(sin + noise2)
            var littleEndianValue2 = value2.littleEndian
            let data2 = Data(bytes: &littleEndianValue2, count: MemoryLayout.size(ofValue: littleEndianValue2))
            
            let noise3 = Double.random(in: -500...500) // Add random noise
            let value3 = UInt32(sin + noise3)
            var littleEndianValue3 = value3.littleEndian
            let data3 = Data(bytes: &littleEndianValue3, count: MemoryLayout.size(ofValue: littleEndianValue3))
            
            let noise4 = Double.random(in: -500...500) // Add random noise
            let value4 = UInt32(sin + noise4)
            var littleEndianValue4 = value4.littleEndian
            let data4 = Data(bytes: &littleEndianValue4, count: MemoryLayout.size(ofValue: littleEndianValue4))
            
            let sampleData = SampleData()
            let _ = try! sampleData.appendNewData(data: data1, position: 14)
            let _ = try! sampleData.appendNewData(data: data2, position: 15)
            let _ = try! sampleData.appendNewData(data: data3, position: 16)
            let _ = try! sampleData.appendNewData(data: data4, position: 17)
            
            // Post the simulated PPG data as a notification
//            NotificationCenter.default.post(name: IncomingWearablePacket.sampleRecievedNotification(deviceId: "mockDeviceId"), object: nil, userInfo: [
//                "timestamp": Date().toISOMillisString(),
//                "sample": sampleData
//            ])
            time += 0.01 // Increment time for next cycle
        }
    }
}
