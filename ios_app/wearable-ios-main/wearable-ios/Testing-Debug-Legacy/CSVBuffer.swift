//
//  CSVBuffer.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/22/23.
//

import Foundation

/** This class aggregates multiple CSVDataRow objects by timestamp, merging them if a row already exists for that timestamp. LEGACY class, only used in `BluetoothTestPeripheralView` */
class CSVBuffer {
    /** A map of timestamp Doubles to their corresponding `CSVDataRow` */
    private var rows: [Double: CSVDataRow] = [:]
    
    /** Add data from a received packet to the buffer */
    func append(_ packet: IncomingWearablePacketLegacy) {
        // Params from packet
        let startUnix = Double(packet.start_unix) // Unix timestamp when device first connected, in seconds
        let startMillis = Double(packet.start_millis) // Milliseconds after startUnix that this packet begins
        let endMillis = Double(packet.end_millis) // Milliseconds after startUnix that this packet ends
        
        let packetStartUnix = startUnix + startMillis/1000 // Unix timestamp when packet starts, in seconds
        let intervalSeconds = (endMillis-startMillis)/1000 // Time between first and last data row of packet, in seconds
        let stepSeconds = intervalSeconds/Double(packet.data.count) // Time between each data row in packet, in seconds
        
        var dataIndex = 0
        for row in packet.data {
            let timestamp = (packetStartUnix + Double(dataIndex)*stepSeconds)
            let rounded = Double(round(1000 * timestamp) / 1000)
            rows[rounded] = row.asCSVDataRow(withExisting: rows[timestamp])
            dataIndex += 1
        }
        
    }
    
    /** Clear the buffer, and export its data as an array of CSV rows, where the first element is the column headers */
    func clear() -> [String] {
        var toReturn: [String] = ["isodate,waypoints,battery,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z,mag_x,mag_y,mag_z,air_temp,thermistor,press,humid,ppg_1,ppg_2"]
        for key in rows.keys.sorted() {
            guard let row = rows[key] else { continue }
            toReturn.append("\(dateAndTimeCSVString(unixSeconds: key)),\(row.csvString)")
        }
        rows = [:]
        return toReturn
    }
    
    /** Converts the given `unixSeconds` to the following formated string:  `"yyyy-MM-ddTHH:mm:ss.SSSZ"`*/
    private func dateAndTimeCSVString(unixSeconds: Double) -> String {
        let date = Date(timeIntervalSince1970: unixSeconds)
        let extraMillis = String(format: "%.3f", unixSeconds).suffix(3)
        return "\(date.ISO8601Format(.iso8601(timeZone: .gmt))).\(extraMillis)Z"
    }
}
