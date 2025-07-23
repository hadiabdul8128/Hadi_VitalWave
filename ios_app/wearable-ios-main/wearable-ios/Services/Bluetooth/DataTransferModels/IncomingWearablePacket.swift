//
//  IncomingWearablePacket.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/20/23.
//

import Foundation

/** An ISO string following the format `"yyyy-MM-ddTHH:mm:ss.SSSZ"` used in the CSVs and other places */
typealias ISOMillisString = String

/** The data structure representing the type of packet we can expect from the wearable. Each packet is ~256 bytes and contains multiple rows of either high, medium, or low-frequency data in the  `data` array. The remaining properties of this struct are packet headers and timing information. This struct also has a custom initializer such that it can be initialized directly from the raw binary `Data` received from the CoreBluetooth API  */
public struct IncomingWearablePacket: CustomStringConvertible {
    enum IncomingWearablePacketType: UInt16 {
        /** Data collected and received close to as soon as it is available */
        case live = 43947 // 0xABAB
        
        /** Data collected by wearable when not connected to iPhone, received at some later date (+a few milliseconds to several weeks) */
        case past = 8995 // 0x2323
        
    }
    private let type: IncomingWearablePacketType
    private let unix_seconds: UInt32
    private let num_samples: UInt16
    
    let samples: [ISOMillisString: SampleData]
    
    /** Converts the given `unixSeconds` to the following formated string:  `"yyyy-MM-ddTHH:mm:ss.SSSZ"`*/
    private static func dateAndTimeCSVString(unixSeconds: UInt32, extraMillis: UInt16) -> ISOMillisString {
        var millis = extraMillis
        var seconds = unixSeconds
        while (millis >= 1000) {
            millis -= 1000
            seconds += 1
        }
        let millisString = String(format: "%03d", millis)
        let date = Date(timeIntervalSince1970: Double(seconds))
        return "\(date.ISO8601Format(.iso8601(timeZone: .gmt))).\(millisString)Z"
    }
    
    init(from data: Data, for peripheralId: String) throws {
        guard data.count > 8 else { throw DataTransferError.invalidPacketHeaderLength }
        
        // Decode header
        guard let type = IncomingWearablePacketType(rawValue: data[0..<2].uint16) else { throw DataTransferError.unknownPacket }
        if type == .live {
            print("[IncomingWearablePacket] Live packet received, decoding now...")
        } else if type == .past {
            print("[IncomingWearablePacket] Past packet received, decoding now...")
        }
        self.type = type
        let unixSeconds = data[2..<6].uint32
        self.unix_seconds = unixSeconds
        guard unix_seconds > 1698434747 // October 27, 2023 7:25:47 PM
                && unix_seconds < 2524607999 // December 31, 2049 11:59:59 PM
        else { throw DataTransferError.unexpectedStartUnix }
        self.num_samples = data[6..<8].uint16
        let sampleData = Data(data[8..<data.count])
        var samplesMutable: [ISOMillisString: SampleData] = [:]
        
        // Decode data with variable-length sample
        var samplePointer = 0 // Keeps track of start of currently parsing sample
        var collectedSamples = 0 // Counter for how many samples have been parsed correctly
        while (collectedSamples < num_samples) {
            guard samplePointer + 9 < sampleData.count else { break }
            
            // Decode constant data always present in a sample: timestamp and select bits. The timestamp is self-explanatory, and the select bits what values to expect in the remainder of the sample
            let millis = sampleData[samplePointer..<samplePointer+2].uint16
            var select = sampleData[samplePointer+2..<samplePointer+6].uint32
            guard select != 0 else {
                print("Sample \(collectedSamples + 1) of \(num_samples) has no data, skipping")
                samplePointer += 6
                collectedSamples += 1
                continue
            }
            
            let samplesForTimestamp = SampleData()
            let timestamp = IncomingWearablePacket.dateAndTimeCSVString(unixSeconds: unixSeconds, extraMillis: millis)
            
            let selectHex = sampleData[samplePointer+2..<samplePointer+6].asHexString()
            print("\nDecoding sample \(collectedSamples + 1) of \(num_samples) for millis \(millis) (\(timestamp)), select 0x\(selectHex) as:")
            
            // Decode data in sample
            var dataPointer = samplePointer + 6 // Points to the value within the sample that we are currently decoding
            var selectPointer = 0 // Keeps track of what bit position of select correspods to the data at dataPointer
            while (select != 0) { // We right-shift the value of select and check for oddness to determine if the bit at selectPointer is 0 or 1
                if (select % 2 == 1) { // If 1, that means its time to decode the data, store it in our human-readable datastructure, and increment the dataPointer
                    guard dataPointer + 4 <= sampleData.count else { throw DataTransferError.dataNotFound }
                    
                    do {
                        let decodedValueString = try samplesForTimestamp.appendNewData(data: sampleData[dataPointer..<dataPointer+4], position: selectPointer)
                        print("\tBit: \(selectPointer) | Hex: 0x\(sampleData[dataPointer..<dataPointer+4].asHexString()) | Decoded: \(decodedValueString)")
                    } catch {
                        print("\tBit: \(selectPointer) | Hex: 0x\(sampleData[dataPointer..<dataPointer+4].asHexString()) | ERROR: \(error)")
                    }
                    dataPointer += 4
                }
                selectPointer += 1
                select = select >> 1
            }
            
            // Once we've decoded an entire sample, we add it to the timestamp dict and move onto the next one
            samplesMutable[timestamp] = samplesForTimestamp
            collectedSamples += 1
            samplePointer = dataPointer
            
        }
        self.samples = samplesMutable
    }
    
    public var description: String {
        return """
            IncomingWearablePacket:
              type: \(type)
              unix_seconds \(unix_seconds)
              num_samples: \(num_samples)
              samples: \(samples)
            """
    }
}

