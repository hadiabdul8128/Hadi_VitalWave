//
//  BluetoothExtensions.swift
//  wearable-ios
//
//  Created by Luke Redmore on 4/23/24.
//

@preconcurrency import CoreBluetooth

extension CBManagerState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .poweredOn: return "POWERED_ON"
        case .poweredOff: return "POWERED_OFF"
        case .resetting: return "RESETTING"
        case .unauthorized: return "UNAUTHORIZED"
        case .unknown: return "UNKNOWN"
        case .unsupported: return "UNSUPPORTED"
        @unknown default:
            return "UNKNOWN (NOT HANDLED)"
        }
    }
}
