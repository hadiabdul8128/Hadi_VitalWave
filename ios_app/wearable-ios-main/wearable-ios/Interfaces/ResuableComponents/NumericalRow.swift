//
//  NumericalRow.swift
//  wearable-ios
//
//  Created by Luke Redmore on 9/30/24.
//

import SwiftUI

enum EmptyValueType {
    case loading, blank
    case text(String)
}

/// A simple `HStack` containing a formatted label and numerical value
struct NumericalRow: View {
    let label: String
    let value: (any WearableDataType)?
    let numDecimals: Int
    let emptyValue: EmptyValueType
    
    init(label: String, value: (any WearableDataType)?, numDecimals: Int) {
        self.label = label
        self.value = value
        self.numDecimals = numDecimals
        self.emptyValue = .blank
    }
    
    init(label: String, value: (any WearableDataType)?, numDecimals: Int, emptyValue: EmptyValueType) {
        self.label = label
        self.value = value
        self.numDecimals = numDecimals
        self.emptyValue = emptyValue
    }
    
    struct MonospacedSecondaryTextModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .foregroundStyle(.secondary)
                .monospaced()
        }
    }
    
    @ViewBuilder
    private var Value: some View {
        if let val = value as? Float32 {
            Text(String(format: "%.\(numDecimals)f", val))
                .modifier(MonospacedSecondaryTextModifier())
        } else if let val = value as? any BinaryInteger {
            let zeroes = numDecimals > 0 ? "." + String.init(repeating: "0", count: numDecimals) : ""
            Text("\(val)\(zeroes)").modifier(MonospacedSecondaryTextModifier())
        } else {
            switch emptyValue {
            case .loading:
                ProgressView().progressViewStyle(.circular)
            case .blank:
                Text("").modifier(MonospacedSecondaryTextModifier())
            case let .text(text):
                Text(text).modifier(MonospacedSecondaryTextModifier())
            }
        }
    }
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Value
        }
    }
}

#Preview {
    NavigationStack {
        List {
            NumericalRow(label: "Float32", value: Float32(5.5), numDecimals: 3)
            NumericalRow(label: "UInt32", value: UInt32(323_000), numDecimals: 3)
            NumericalRow(label: "UInt8", value: UInt8(133), numDecimals: 0)
            NumericalRow(label: "Empty", value: nil, numDecimals: 3, emptyValue: .text("Waiting"))
            NumericalRow(label: "Empty", value: nil, numDecimals: 3, emptyValue: .loading)
            Button { } label: {
                NumericalRow(label: "Button", value: 5.5 as Float, numDecimals: 3)
            }
            NavigationLink {
                NumericalRow(label: "Surprise!", value: 5.5 as Float, numDecimals: 3)
            } label : {
                NumericalRow(label: "Link", value: 5.5 as Float, numDecimals: 3)
            }
            NavigationLink {
                NumericalRow(label: "Surprise!", value: 5.5 as Float, numDecimals: 3)
            } label : {
                NumericalRow(label: "Link Empty", value: nil, numDecimals: 3)
            }
            
            NavigationLink {
                NumericalRow(label: "Surprise!", value: 5.5 as Float, numDecimals: 3)
            } label : {
                NumericalRow(label: "Link Empty", value: nil, numDecimals: 3, emptyValue: .loading)
            }
        }
    }
}
