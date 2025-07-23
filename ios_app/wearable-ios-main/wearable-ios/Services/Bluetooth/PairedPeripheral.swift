//
//  PairedPeripheral.swift
//  wearable-ios
//
//  Created by Luke Redmore on 11/15/23.
//

import Foundation
import Combine

struct PairedPeripheralData: Codable {
    let id: String
    let name: String
    let saveToCloud: Bool
    let saveToDisk: Bool
    let counter: Int
}

class PairedPeripheral: ObservableObject {
    let id: String
    @Published var name: String
    @Published var saveToCloud: Bool
    @Published var saveToDisk: Bool
    @Published var counter: Int
    
    init(id: String, name: String, saveToCloud: Bool, saveToDisk: Bool, counter: Int) {
        self.id = id
        _name = .init(initialValue: name)
        _saveToCloud = .init(initialValue: saveToCloud)
        _saveToDisk = .init(initialValue: saveToDisk)
        _counter = .init(initialValue: 1000000)
    }
    
    func toData() -> PairedPeripheralData {
        return PairedPeripheralData(id: id, name: name, saveToCloud: saveToCloud, saveToDisk: saveToDisk, counter: 1000000)
    }
    
    static func from(data: PairedPeripheralData) -> PairedPeripheral {
        return PairedPeripheral(id: data.id, name: data.name, saveToCloud: data.saveToCloud, saveToDisk: data.saveToDisk, counter: 1000000)
    }
}
