//
//  BluetoothTestView.swift
//  wearable-ios
//
//  Created by Luke Redmore on 9/20/23.
//

import SwiftUI
import CoreBluetooth
import os

class ExpandedPeripheral: ObservableObject, Equatable, Hashable {
    static func == (lhs: ExpandedPeripheral, rhs: ExpandedPeripheral) -> Bool {
        lhs.proper == rhs.proper
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
    
    let proper: CBPeripheral
    var rssi: Int
    @Published var isConnected = false
    
    init(_ peripheral: CBPeripheral, rssi: NSNumber) {
        self.proper = peripheral
        self.rssi = rssi.intValue
    }
}

class BluetoothViewModel: NSObject, ObservableObject {
    var centralManager: CBCentralManager?
    @Published var peripherals: [ExpandedPeripheral] = []
    
    func getPeripheral(byUUID uuid: String) -> ExpandedPeripheral? {
        peripherals.first { obj in obj.proper.identifier.uuidString == uuid }
    }
    
    func getPeripheral(byCBPeripheral peripheral: CBPeripheral) -> ExpandedPeripheral? {
        peripherals.first { obj in obj.proper == peripheral }
    }
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionRestoreIdentifierKey: "wearable-ios-ble-background-test"])
    }
    
    
}

extension BluetoothViewModel: CBCentralManagerDelegate {
    
    func clearPeripherals() {
        peripherals = []
    }
    func refresh(_ centralOpt: CBCentralManager? = nil) {
        let central = centralOpt ?? self.centralManager
        // maybe switch on other connection states?
        if central?.state == .poweredOn {
            self.centralManager?.scanForPeripherals(withServices: [CBUUIDs.BLEService_UUID])
        }
    }
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        refresh(central)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered peripheral")
        let expandedPeripheral = ExpandedPeripheral(peripheral, rssi: RSSI)
        if !peripherals.contains(expandedPeripheral) {
            peripherals.append(expandedPeripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("peripheral failed to connect")
        getPeripheral(byCBPeripheral: peripheral)?.isConnected = false
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        centralManager?.stopScan()
        print("peripheral connected!")
        getPeripheral(byCBPeripheral: peripheral)?.isConnected = true
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("peripheral disconnected!")
        getPeripheral(byCBPeripheral: peripheral)?.isConnected = false
    }
    
    func connect(_ peripheral: CBPeripheral) {
        centralManager?.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ])
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ble-background-test")
        guard let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] else {
            logger.error("Could not cast to array of peripherals!")
            return
        }
        let viewModelDelegates = peripherals.map {
            PeripheralViewModel($0, logger: logger)
        }
    }
}

struct BluetoothTestView: View {
    @ObservedObject private var bluetoothViewModel = BluetoothViewModel()
    
    var body: some View {
        NavigationStack {
            List(bluetoothViewModel.peripherals, id: \.proper.identifier) { peripheral in
                NavigationLink("\(peripheral.proper.name ?? "Unknown Device") (\(peripheral.proper.identifier.uuidString))", value: peripheral)
            }
            .refreshable {
                bluetoothViewModel.clearPeripherals()
                bluetoothViewModel.refresh()
                bluetoothViewModel.centralManager?.scanForPeripherals(withServices: [CBUUIDs.BLEService_UUID])
            }
            .navigationDestination(for: ExpandedPeripheral.self) { peripheral in
                BluetoothTestPeripheralView(
                    peripheral: peripheral,
                    centralManager: bluetoothViewModel.centralManager
                )
            }
            .navigationTitle("Peripherals")
        }
    }
}

#Preview {
    BluetoothTestView()
}
