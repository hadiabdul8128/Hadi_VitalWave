//
//  DataTransferError.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/20/23.
//

import Foundation

/** A collection of `Errors` that might be thrown when decoding an incoming packet */
enum DataTransferError: Error {
    case invalidPacketHeaderLength
    case unexpectedStartUnix
    case unknownPacket
    case numSamplesTooBig
    case unknownDataType
    case dataNotFound
    case sensorError
    
    // Legacy
    case invalidPacketDataLength
    case unknownPacketType
}
