//
//  DeviceBatteryListener.swift
//  wearable-ios
//
//  Created by Luke Redmore on 1/23/24.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

/** Listen for changes under Firestore/devices/{deviceId}/battery in .value after .listen() is called */
class DeviceBatteryListener: ObservableObject {
    @Published var value: Int?
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration? = nil
    
    func listen(deviceId: String) {
        self.listener = db.collection("devices").document(deviceId).addSnapshotListener { (querySnapshot, error) in
            guard let deviceData = querySnapshot?.data() else {
                print("[DeviceBatteryListener] No data")
                self.value = nil
                return
            }
            
            if let battery = deviceData["battery"] as? Int {
                print("[DeviceBatteryListener] Found battery", battery)
                self.value = battery
            } else {
                print("[DeviceBatteryListener] Could not find battery param", deviceData)
                self.value = nil
            }
        }

    }
    
    func stopListening() {
        self.listener?.remove()
    }
}
