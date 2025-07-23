//
//  PairedPeripheralManager.swift
//  wearable-ios
//
//  Created by Luke Redmore on 11/10/24.
//

import Foundation
import Combine

class PairedPeripheralManager: ObservableObject {
    @Published var peripherals: [PairedPeripheral] = [] {
        didSet { scheduleSave() }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var saveCancellable: AnyCancellable?
    private static let saveQueue = DispatchQueue(label: "pairedPeripheralManager.saveQueue")
    
    init() {
        loadAll()
        observePeripheralChanges()
    }
    
    private func observePeripheralChanges() {
        peripherals.forEach { peripheral in
            peripheral.objectWillChange
                .sink { [weak self] _ in self?.scheduleSave() }
                .store(in: &cancellables)
        }
    }
    
    private func scheduleSave() {
        saveCancellable?.cancel()
        saveCancellable = Just(())
            .delay(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveAll()
            }
    }
    
    private func saveAll() {
        let dataToSave = peripherals.map { $0.toData() }
        Self.saveQueue.async {
            if let encodedData = try? JSONEncoder().encode(dataToSave) {
                UserDefaults.standard.set(encodedData, forKey: "pairedPeripherals")
            }
        }
    }
    
    private func loadAll() {
        if let savedData = UserDefaults.standard.data(forKey: "pairedPeripherals"),
           let decodedData = try? JSONDecoder().decode([PairedPeripheralData].self, from: savedData) {
            peripherals = decodedData.map { PairedPeripheral.from(data: $0) }
            observePeripheralChanges() // Re-establish observation after loading
        }
    }
    
    static func pairedPeripheralWithId(deviceId id: String) -> PairedPeripheralData? {
        guard let savedData = UserDefaults.standard.data(forKey: "pairedPeripherals"),
              let decodedData = try? JSONDecoder().decode([PairedPeripheralData].self, from: savedData) else { return nil }
        return decodedData.first { $0.id == id }
    }
}
