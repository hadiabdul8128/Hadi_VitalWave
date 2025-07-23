//
//  BluetoothTestPeripheralView.swift
//  wearable-ios
//
//  Created by Luke Redmore on 9/20/23.
//

import SwiftUI
import CoreBluetooth
import os


class PeripheralViewModel: NSObject, ObservableObject {
    private var peripheral: CBPeripheral
    @Published var services: [CBService] = []
    @Published var characteristics: [CBCharacteristic] = []
    @Published var rxCharacteristic: CBCharacteristic? = nil
    @Published var txCharacteristic: CBCharacteristic? = nil
    let csvBuffer = CSVBuffer()
    @Published var receivedPackets = 0
    private var logger: Logger
    
    init(_ peripheral: CBPeripheral, logger: Logger? = nil) {
        self.logger = logger ?? Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ble-default")
        self.peripheral = peripheral
        super.init()
        self.peripheral.delegate = self
    }
}

extension PeripheralViewModel: CBPeripheralDelegate {
    /*
     *  The Transfer Service was discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("Error discovering services: \(error.localizedDescription, privacy: .public)")
//            cleanup()
            return
        }
        
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        guard let peripheralServices = peripheral.services else { return }
        services = peripheralServices
        logger.info("Discovered \(peripheralServices.count) services!")
        
        // Discover charactersitics for each service
        for service in peripheralServices {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    
    /*
     *  The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any).
        if let error = error {
            logger.error("Error discovering services: \(error.localizedDescription, privacy: .public)")
            //            cleanup()
            return
        }
        
        logger.info("Discovered characteristic!")
        
        // Again, we loop through the array, just in case and check if it's the right one
        guard let serviceCharacteristics = service.characteristics else { return }
        for characteristic in serviceCharacteristics where !characteristics.contains(where: { $0.uuid == characteristic.uuid }) {
            characteristics.append(characteristic)
        }
        for characteristic in serviceCharacteristics where characteristic.uuid == CBUUIDs.BLE_Characteristic_uuid_Rx {
            // If it is, subscribe to it
            rxCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
            peripheral.readValue(for: characteristic)
            print("RX Characteristic: \(characteristic.uuid)")
        }
        for characteristic in serviceCharacteristics where characteristic.uuid == CBUUIDs.BLE_Characteristic_uuid_Tx {
            // If it is, subscribe to it
            txCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
            peripheral.readValue(for: characteristic)
            print("TX Characteristic: \(characteristic.uuid)")
        }
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    /*
     *   This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Error updating values for characteristic: \(error.localizedDescription, privacy: .public)")
            return
        }
        
        guard characteristic == rxCharacteristic,  // don't do anything if not rx channel
              let characteristicData = characteristic.value
        else { return } // break if any of this is null
        
        if characteristicData.count < 10 {
            logger.info("Received \(characteristicData.count, privacy: .public) bytes: 0x\(characteristicData.asHexString())")
            return
        } else {
            logger.info("Received \(characteristicData.count, privacy: .public) bytes. Attempting to decode packet...")
        }
        
        do {
            let packet = try IncomingWearablePacketLegacy(from: characteristicData)
            logger.info("Packet decoded!")
            print(packet)
            receivedPackets += 1
            csvBuffer.append(packet)
        } catch {
            logger.info("Invalid packet with error \(error): 0x\(characteristicData.asHexString(), privacy: .public)")
        }
    }
    
    func writeOutgoingData(_ data: Data){
        if let char = txCharacteristic {
            self.peripheral.writeValue(data, for: char, type: CBCharacteristicWriteType.withResponse)
            print("Wrote data!")
        }
    }
}

struct BluetoothTestPeripheralView: View {
    @EnvironmentObject private var authModel: AuthViewModel
    @ObservedObject var peripheral: ExpandedPeripheral
    let centralManager: CBCentralManager?
    @ObservedObject var peripheralViewModel: PeripheralViewModel
    
    init(peripheral: ExpandedPeripheral, centralManager: CBCentralManager?) {
        self.peripheral = peripheral
        self.centralManager = centralManager
        self.peripheralViewModel = PeripheralViewModel(peripheral.proper)
    }
    
    var body: some View {
        VStack {
            Text(peripheral.proper.identifier.uuidString)
            Text("RSSI: \(peripheral.rssi)")
            if peripheral.isConnected {
                Text("Connection Status: Connected")
                Text("Services: ").font(.headline)
                List(peripheralViewModel.services, id: \.uuid) { service in
                    Text("\(service.uuid): (\(service.description)")
                }
                Divider()
                Text("Characteristics: ").font(.headline)
                List(peripheralViewModel.characteristics, id: \.uuid) { characteristic in
                    Text("\(characteristic.uuid): (\(characteristic.description)")
                }
                Divider()
                Text("Received \(peripheralViewModel.receivedPackets) valid packets")
                Divider()
                Spacer()
                Button("Upload CSV") {
                    Task {
                        guard let uid = authModel.user?.uid else {
                            print("No user!")
                            return
                        }
                        let csvData = peripheralViewModel.csvBuffer.clear()
                        print("[CSV] Uploading \(peripheralViewModel.receivedPackets) valid packets as CSV")
                        peripheralViewModel.receivedPackets = 0
                        await FirebaseDeviceDataUploaderService.upload(userId: uid, deviceId: peripheral.proper.identifier.uuidString, filename: Date.now.ISO8601Format(), fileExtension: "csv", contents: csvData.joined(separator: "\n"))
                    }
                }
                Button("Disconnect") {
                    centralManager?.cancelPeripheralConnection(peripheral.proper)
                }
                Button("Write date") {
                    let value = UInt32(Date().timeIntervalSince1970)
                    var u32LE = value.littleEndian // or simply value
                    let dataLE = Data(bytes: &u32LE, count: 4)
                    peripheralViewModel.writeOutgoingData(dataLE)
                }
            } else {
                Text("Connection Status: Not Connected")
                Button("Connect") {
                    centralManager?.connect(peripheral.proper)
                }
            }
        }
        
    }
}

//#Preview {
//    BluetoothTestPeripheralView()
//}
