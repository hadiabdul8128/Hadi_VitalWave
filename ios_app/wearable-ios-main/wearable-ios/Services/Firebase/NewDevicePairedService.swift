//
//  NewDevicePairedService.swift
//  wearable-ios
//
//  Created by Luke Redmore on 2/19/24.
//

import FirebaseCore
import FirebaseFirestore

/** Add new device to Firestore with basic data */
class NewDevicePairedService {
    
    /** Add new device to Firestore with basic data */
    static func addNewDevice(deviceId: String) async {
        let db = Firestore.firestore()
        do {
          try await db.collection("devices").document(deviceId).setData([
            "battery": 100
          ])
          print("Device Document successfully written!")
        } catch {
          print("Error writing document: \(error)")
        }
    }
}
