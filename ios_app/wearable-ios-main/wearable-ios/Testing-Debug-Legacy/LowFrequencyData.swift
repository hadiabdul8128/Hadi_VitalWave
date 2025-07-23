//
//  LowFrequency.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/19/23.
//

import Foundation

struct LowFrequencyData: IncomingWearableData {
    static var sizeInBytes: Int = 16
    static var rowsPerPacket: Int = 14
    static var initializer: (Data) throws -> IncomingWearableData = LowFrequencyData.init
    
    let waypoints: UInt8;
    let battery: UInt8;
    let thermistor: UInt16;
    let air_temp: Float32;
    let press: Float32;
    let humid: Float32;
    
    init(from data: Data) throws {
        self.waypoints = data[0..<1].uint8
        self.battery = data[1..<2].uint8
        self.thermistor = data[2..<4].uint16
        self.air_temp = data[4..<8].float32
        self.press = data[8..<12].float32
        self.humid = data[12..<16].float32
    }
    
    func asCSVDataRow(withExisting existing: CSVDataRow?) -> CSVDataRow {
        let row = existing ?? CSVDataRow()
        row.waypoints = waypoints
        row.battery = battery
        row.thermistor = thermistor
        row.air_temp = air_temp
        row.press = press
        row.humid = humid
        return row
    }
    
    
    var description: String {
            """
            Low Frequency Data:
              Waypoints: \(waypoints)
              Battery: \(battery)
              Thermistor: \(thermistor)
              Air Temperature: \(air_temp)
              Pressure: \(press)
              Humidity: \(humid)
            """
    }
    
    var shortDescription: String {
        "LowFrequencyData: [\(waypoints)\t\(battery)\t\(thermistor)\t\(air_temp)\t\(press)\t\(humid)]"
    }
}
