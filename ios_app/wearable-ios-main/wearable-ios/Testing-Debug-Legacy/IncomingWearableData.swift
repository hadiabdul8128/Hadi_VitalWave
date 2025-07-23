//
//  IncomingWearableData.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/20/23.
//

import Foundation

/** This protocol represents any data format that is passed from the wearable. The properties required by this protocol are used by the `IncomingWearablePacket` decoder as well as the `IncomingDataBuffer` to determine the type or size of data it is decoding */
protocol IncomingWearableData: CustomStringConvertible {
    
    /** The size of the datastream of one row of this object, in bytes */
    static var sizeInBytes: Int { get }
    
    /** The number of rows of data a packet will contain */
    static var rowsPerPacket: Int { get }
    
    /** The initializer of the function from raw Data*/
    static var initializer: (_ from: Data) throws -> IncomingWearableData { get }
    
    /** A space-delimited list of entries of the object*/
    var shortDescription: String { get }
    
    func asCSVDataRow(withExisting: CSVDataRow?) -> CSVDataRow
}
