//
//  BLEModel-Peripheral.swift
//  wearable-ios
//
//  Created by Luke Redmore on 11/16/23.
//

import Foundation
import Combine
@preconcurrency import AsyncBluetooth

extension BLEModel {
    private func writeDate(to peripheral: Peripheral) async throws {
        let value = UInt32(Date().timeIntervalSince1970)
        var u32LE = value.littleEndian // or simply value
        let dataLE = Data(bytes: &u32LE, count: 4)
        
        try await peripheral.writeValue(
            dataLE,
            forCharacteristicWithCBUUID: CBUUIDs.BLE_Characteristic_uuid_Tx,
            ofServiceWithCBUUID: CBUUIDs.BLEService_UUID
        )
        print("Wrote date to device")
    }
    
    private func subscribeToCharacteristic(_ peripheral: Peripheral) async throws {
        try await peripheral.setNotifyValue(
            true,
            forCharacteristicWithCBUUID: CBUUIDs.BLE_Characteristic_uuid_Rx,
            ofServiceWithCBUUID: CBUUIDs.BLEService_UUID
        )
        
        let dataBuffer = IncomingDataBuffer(deviceId: peripheral.identifier.uuidString)
        
        peripheral.characteristicValueUpdatedPublisher
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .filter { $0.uuid == CBUUIDs.BLE_Characteristic_uuid_Rx }
            .map {
                do {
                    guard let data = try $0.parsedValue() as Data? else { return nil as IncomingWearablePacket? }
                    let packet = try IncomingWearablePacket(from: data, for: peripheral.identifier.uuidString) //, packetCount: self.packetCount)
                    // TODO: Verify all packets are being received in order in debug mode here
                    return packet as IncomingWearablePacket?
                } catch {
                    print("Could not decode packet:", error)
                    return nil as IncomingWearablePacket?
                }
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] (value: IncomingWearablePacket?) in
                guard let self = self, let packet = value else { return }
                let _ = dataBuffer.append(packet)
                for (timestampStr, sample) in packet.samples.sorted(by: { $0.key < $1.key } ) {
                    print("[SENT SAMPLE] at \(timestampStr)")
                    guard let timestamp = Date.fromISOMillisString(timestampStr) else { continue }
                    self.samplePublisher.send((peripheral.identifier.uuidString, timestamp, sample))
                    
                }
                print("Found packet!")
            })
            .store(in: &cancellables)
    }
    
    
    internal func onPeripheralConnect(_ peripheral: Peripheral) {
        Task {
            do {
                try await writeDate(to: peripheral)
            } catch {
                print("Could not send date: \(error)")
            }
            
            do {
                try await subscribeToCharacteristic(peripheral)
            } catch {
                print("Could not subscribe to characteristic: \(error)")
            }
            
            
        }
    }
}
