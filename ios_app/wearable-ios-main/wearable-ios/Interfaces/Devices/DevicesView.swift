//
//  DevicesView.swift
//  wearable-ios
//
//  Created by Aseda Asomani on 10/3/23.
//

import Foundation
import SwiftUI
import os

/** Lists all currently paired devices, as well as entry point for adding/removing devices */
struct DevicesView: View {
    @State private var addingDevice = false
    @EnvironmentObject private var bleModel: BLEModel
    
    var stateName: String { String(reflecting: bleModel.bleState) }
    
    var body: some View {
        NavigationStack {
            ZStack() {
                List {
                    Section {
                        ForEach($bleModel.pairedPeripheralManager.peripherals, id: \.id) { PairedDeviceRow(pairedPeripheral: $0) }
                    } footer: {
                        switch bleModel.bleState {
                        case .poweredOn:
                            bleModel.pairedPeripheralManager.peripherals.count > 0
                            ? Text("To reconnect a device, place it in pairing mode, then pull to refresh. You may also swipe left on any row to forget that device")
                            : Text("Click the plus button to add a device.")
                        default:
                            Text("Cannot connect to Bluetooth (BLE state is \(stateName)). Please ensure Bluetooth is turned on and enabled for this app in order to connect to devices.")
                        }
                    }
                }
                .refreshable { bleModel.connectToPairedPeripherals() }
                .onChange(of: bleModel.bleState) { oldValue, newValue in
                    if newValue != .poweredOn { addingDevice = false }
                }
                bleModel.bleState == .poweredOn ? FloatingButton() { addingDevice.toggle() } : nil
            }.sheet(isPresented: $addingDevice) {
                AddDeviceView().interactiveDismissDisabled()
            }.navigationTitle("Devices")
        }
    }
}

#Preview {
    DevicesView().environmentObject(BLEModel())
}
