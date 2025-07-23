//
//  AddDeviceView.swift
//  wearable-ios
//
//  Created by Luke Redmore on 11/14/23.
//

import SwiftUI
import AsyncBluetooth

struct AddDeviceView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var bleModel: BLEModel
    @State private var alertText: String? = nil
    
    var body: some View {
        
        // Computed binding Bool to show the alert if `alertText` is set
        let showAlert = Binding(
            get: { self.alertText != nil },
            set: { self.alertText = $0 ? self.alertText : nil }
        )
        
        VStack {
            HStack {
                Text("Pair New Device").font(.largeTitle).bold()
                Spacer()
                Button("Close") { dismiss() }
            }.padding()
            if let newPeripherals = bleModel.unknownPeripherals, newPeripherals.count > 0 {
                Text("Tap a device below to pair it")
                List(newPeripherals, id: \.identifier) { peripheral in
                    AddDeviceRow(peripheral: peripheral) {
                        alertText = $0
                    }
                }
                .refreshable {
                    bleModel.stopScan()
                    bleModel.startScan()
                }
            } else if bleModel.unknownPeripherals != nil {
                Spacer()
                HStack {
                    Text("Searching for devices...")
                    ProgressView().padding(.leading)
                }
                Text("Please bring a supported device nearby and place it in pairing mode")
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Refresh") {
                    bleModel.stopScan()
                    bleModel.startScan()
                }
                Spacer()
            } else {
                Spacer()
                Text("Loading...")
                ProgressView()
                Spacer()
            }
            // If running in debug, show a dummy device to "pair" with
//#if DEBUG
//            List {
//                Section(footer: Text("DEBUG DEVICES (for pairing only, cannot be connected to)")) {
//                    Button {
//                        
//                        let peripheralToAdd = PairedPeripheral(id: "C469026-0B57-27B9-153F-473A48299CAA", name: "Feather Sense Debug", saveToCloud: true, saveToDisk: true)
//                        var newPairedPeripheralsArray = bleModel.pairedPeripherals
//                        if !newPairedPeripheralsArray.contains(peripheralToAdd) {
//                            newPairedPeripheralsArray.append(peripheralToAdd)
//                            bleModel.pairedPeripherals = newPairedPeripheralsArray
//                        }
//                        alertText = "Successfully paired \(peripheralToAdd.name)!"
//                    } label: {
//                        Text("C469026-0B57-27B9-153F-473A48299CAA")
//                    }
//                }
//            }
//#endif
        }
        .onAppear { bleModel.startScan() }
        .onDisappear { if bleModel.bleState == .poweredOn { bleModel.stopScan() } }
        .alert(alertText ?? "", isPresented: showAlert) { }
    }
}

struct AddDeviceRow: View {
    @EnvironmentObject private var bleModel: BLEModel
    @State private var pairing = false
    
    let peripheral: Peripheral
    let afterTapAction: (_ statusMessage: String) -> Void
    
    @ViewBuilder
    func DeviceLabel() -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(peripheral.name ?? "Unknown Device")
                Text(peripheral.identifier.uuidString).font(.caption)
            }
            if pairing {
                Spacer()
                ProgressView()
            }
        }
        
    }
    
    var body: some View {
        Button(action: {
            Task {
                if pairing { return }
                pairing = true
                do {
                    try await bleModel.pair(newPeripheral: peripheral)
                    await NewDevicePairedService.addNewDevice(deviceId: peripheral.identifier.uuidString)
                    afterTapAction("Successfully paired \(peripheral.name ?? "Unknown Device")!")
                } catch {
                    afterTapAction("Failed to pair \(peripheral.name ?? "Unknown Device")")
                }
                pairing = false
            }
        }, label: DeviceLabel)
        .buttonStyle(.plain)
    }
    
}

#Preview {
    AddDeviceView()
}
