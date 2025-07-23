//
//  IncomingWearablePacketLegacy.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/20/23.
//

import Foundation

/** The data structure representing the type of packet we can expect from the wearable. Each packet is ~256 bytes and contains multiple rows of either high, medium, or low-frequency data in the  `data` array. The remaining properties of this struct are packet headers and timing information. This struct also has a custom initializer such that it can be initialized directly from the raw binary `Data` received from the CoreBluetooth API  */
struct IncomingWearablePacketLegacy: CustomStringConvertible {
    let type: UInt8
    let start_unix: UInt32
    let start_millis: UInt32
    let end_millis: UInt32
    let data: [IncomingWearableData]
    
    init(from data: Data) throws {
        guard data.count > 13 else { throw DataTransferError.invalidPacketHeaderLength }
        
        // Decode header
        self.type = data[0..<1].uint8
        self.start_unix = data[1..<5].uint32
        guard start_unix > 1698434747 // October 27, 2023 7:25:47 PM
            && start_unix < 2524607999 // December 31, 2049 11:59:59 PM
        else { throw DataTransferError.unexpectedStartUnix }
        self.start_millis = data[5..<9].uint32
        self.end_millis = data[9..<13].uint32
        
        // Determine data type
        let packetDataType: IncomingWearableData.Type
        switch (self.type) {
            case 1: packetDataType = LowFrequencyData.self
            case 2: packetDataType = MediumFrequencyData.self
            case 4: packetDataType = HighFrequencyData.self
            default: throw DataTransferError.unknownPacketType
        }
        
        // Validate and decode data rows
        let dataRowSize = packetDataType.sizeInBytes
        let numberOfRows = packetDataType.rowsPerPacket
        var decodedDataRows: [IncomingWearableData] = []
        for i in stride(from: 13, to: 13 + numberOfRows * dataRowSize, by: dataRowSize) {
            guard data.count >= i+dataRowSize else { throw DataTransferError.invalidPacketDataLength }
            let rowData = Data(data[i..<(i+dataRowSize)])
            let decodedRow = try packetDataType.initializer(rowData)
            decodedDataRows.append(decodedRow)
        }
        self.data = decodedDataRows
    }
    
    var description: String {
        var dataDescription = "[\n"
        for dataRow in data {
            dataDescription += "\t" + dataRow.shortDescription + "\n"
        }
        
        dataDescription += "]"
        
        return """
            IncomingWearablePacket:
              Type: \(type)
              Start Unix: \(start_unix)
              Start Millis: \(start_millis)
              End Millis: \(end_millis)
              Data: \(dataDescription)
            """
    }
}
