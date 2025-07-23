//
//  HighFrequency.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/20/23.
//

import Foundation

struct HighFrequencyData: IncomingWearableData {
    static var sizeInBytes: Int = 20
    static var rowsPerPacket: Int = 11
    static var initializer: (Data) throws -> IncomingWearableData = HighFrequencyData.init
    
    let acc_x: Float32
    let acc_y: Float32
    let acc_z: Float32
    let ppg_1: UInt32
    let ppg_2: UInt32
    
    init(from data: Data) throws {
        self.acc_x = data[0..<4].float32
        self.acc_y = data[4..<8].float32
        self.acc_z = data[8..<12].float32
        self.ppg_1 = data[12..<16].uint32
        self.ppg_2 = data[16..<20].uint32
    }
    
    func asCSVDataRow(withExisting existing: CSVDataRow?) -> CSVDataRow {
        let row = existing ?? CSVDataRow()
        row.acc_x = acc_x
        row.acc_y = acc_y
        row.acc_z = acc_z
        row.ppg_1 = ppg_1
        row.ppg_2 = ppg_2
        return row
    }
    
    
    var description: String {
            """
            High Frequency Data:
              acc_x: \(acc_x)
              acc_y: \(acc_y)
              acc_z: \(acc_z)
              ppg_1: \(ppg_1)
              ppg_2: \(ppg_2)
            """
    }
    
    var shortDescription: String {
        "HighFrequencyData: [\(acc_x)\t\(acc_y)\t\(acc_z)\t\(ppg_1)\t\(ppg_2)]"
    }
}
