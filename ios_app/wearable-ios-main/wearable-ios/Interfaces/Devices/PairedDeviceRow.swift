//
//  PairedDeviceRow.swift
//  wearable-ios
//
//  Created by Luke Redmore on 1/23/24.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct PairedDeviceRow: View {
    @EnvironmentObject private var bleModel: BLEModel
    @StateObject private var batteryListener = DeviceBatteryListener()
    @Binding var pairedPeripheral: PairedPeripheral
        
    
    var isConnected: Bool { bleModel.connectedPeripherals.contains { $0.identifier.uuidString == pairedPeripheral.id } }
    
    var body: some View {
        NavigationLink {
            DeviceDetailView(deviceDetails: $pairedPeripheral)
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Text(pairedPeripheral.name)
                    Text(pairedPeripheral.id).font(.caption)
                }
                Spacer()
                if let battery = batteryListener.value, isConnected {
                    Text(String(battery))
                }
                Circle()
                    .fill(isConnected ? .green : .gray)
                    .frame(width: 10, height: 10)
            }
        }
        .swipeActions {
            Button("Forget", role: .destructive) {
                Task {
                    await bleModel.forget(pairedPeripheral: pairedPeripheral)
                }
            }
        }
        .onAppear {
            batteryListener.listen(deviceId: pairedPeripheral.id)
        }
        .onDisappear {
            batteryListener.stopListening()
        }
    }
}

//#Preview {
//    PairedDeviceRow()
//}
