//
//  MediumFrequency.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/20/23.
//

import Foundation

struct MediumFrequencyData: IncomingWearableData {
    static var sizeInBytes: Int = 24
    static var rowsPerPacket: Int = 9
    static var initializer: (Data) throws -> IncomingWearableData = MediumFrequencyData.init
    
    let gyro_x: Float32;
    let gyro_y: Float32;
    let gyro_z: Float32;
    let mag_x: Float32;
    let mag_y: Float32;
    let mag_z: Float32;
    
    init(from data: Data) throws {
        self.gyro_x = data[0..<4].float32
        self.gyro_y = data[4..<8].float32
        self.gyro_z = data[8..<12].float32
        self.mag_x = data[12..<16].float32
        self.mag_y = data[16..<20].float32
        self.mag_z = data[20..<24].float32
    }
    
    func asCSVDataRow(withExisting existing: CSVDataRow?) -> CSVDataRow {
        let row = existing ?? CSVDataRow()
        row.gyro_x = gyro_x
        row.gyro_y = gyro_y
        row.gyro_z = gyro_z
        row.mag_x = mag_x
        row.mag_y = mag_y
        row.mag_z = mag_z
        return row
    }
    
    var description: String {
            """
            Medium Frequency Data:
              gyro_x: \(gyro_x)
              gyro_y: \(gyro_y)
              gyro_z: \(gyro_z)
              mag_x: \(mag_x)
              mag_y: \(mag_y)
              mag_z: \(mag_z)
            """
    }
    
    var shortDescription: String {
        "MediumFrequencyData: [\(gyro_x)\t\(gyro_y)\t\(gyro_z)\t\(mag_x)\t\(mag_y)\t\(mag_z)]"
    }
}
