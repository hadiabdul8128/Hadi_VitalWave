//
//  CSVDataRow.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/22/23.
//

import Foundation

/** This class represents a single row in the CSV to send to the server. It does not include timestamp because timestamp is added at the very end */
class CSVDataRow {
    var waypoints: UInt8?
    var battery: UInt8?
    var acc_x: Float32?
    var acc_y: Float32?
    var acc_z: Float32?
    var gyro_x: Float32?
    var gyro_y: Float32?
    var gyro_z: Float32?
    var mag_x: Float32?
    var mag_y: Float32?
    var mag_z: Float32?
    var air_temp: Float32?
    var thermistor: UInt16?
    var press: Float32?
    var humid: Float32?
    var ppg_1: UInt32?
    var ppg_2: UInt32?
    
    init() { }
            
    private func valOrBlank(_ val: CustomStringConvertible?) -> String {
        guard let present = val else { return "" }
       return present.description
    }
    
    var csvString: String {
        [
            valOrBlank(waypoints),
            valOrBlank(battery),
            valOrBlank(acc_x),
            valOrBlank(acc_y),
            valOrBlank(acc_z),
            valOrBlank(gyro_x),
            valOrBlank(gyro_y),
            valOrBlank(gyro_z),
            valOrBlank(mag_x),
            valOrBlank(mag_y),
            valOrBlank(mag_z),
            valOrBlank(air_temp),
            valOrBlank(thermistor),
            valOrBlank(press),
            valOrBlank(humid),
            valOrBlank(ppg_1),
            valOrBlank(ppg_2)
        ].joined(separator: ",")
    }
    
    
}

