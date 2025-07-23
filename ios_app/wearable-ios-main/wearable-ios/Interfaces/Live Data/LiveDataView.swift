//
//  LiveDataView.swift
//  wearable-ios
//
//  Created by Luke Redmore on 12/6/23.
//

import SwiftUI

/** This view displays live data from each device*/
struct LiveDataView: View {
    @EnvironmentObject private var bleModel: BLEModel
    
    var body: some View {
        NavigationStack{
            if bleModel.connectedPeripherals.isEmpty {
                Text("Connect to a device to view realtime data here")
                    .padding()
                    .multilineTextAlignment(.center)
                    .navigationTitle("Live Data")
            } else {
                List {
                    ForEach(bleModel.pairedPeripheralManager.peripherals, id:\.id) { periph in
                        if (bleModel.connectedPeripherals.contains(where: { $0.identifier.uuidString == periph.id })) {
                            LiveDataViewSingle(peripheral: periph)
                        }
                    }
                }.navigationTitle("Live Data")
            }
        }
    }
}

#Preview {
    LiveDataView()
}
