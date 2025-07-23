//
//  LiveDataRow.swift
//  wearable-ios
//
//  Created by Luke Redmore on 9/18/24.
//

import SwiftUI

struct LiveDataRowLabel<T: WearableDataType>: View {
    @EnvironmentObject private var bleModel: BLEModel
    private let peripheralId: String
    private let label: String
    private let numDecimals: Int
    private let path: KeyPath<SampleData, T?>
    @State var value: T? = nil
    
    init(_ peripheralId: String, label: String, numDecimals: Int, path: KeyPath<SampleData, T?>) {
        self.peripheralId = peripheralId
        self.label = label
        self.numDecimals = numDecimals
        self.path = path
    }
    
    var body: some View {
        NumericalRow(label: label, value: value, numDecimals: numDecimals)
            .onReceive(bleModel.samplePublisher) { (deviceId, _, sample) in
                guard deviceId == peripheralId, let parsed = sample[keyPath: path] else { return }
                value = parsed
            }
    }
}
