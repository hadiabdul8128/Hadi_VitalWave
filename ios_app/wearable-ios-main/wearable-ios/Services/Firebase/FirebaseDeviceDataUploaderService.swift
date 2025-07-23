//
//  FirebaseDeviceDataUploaderService.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/5/23.
//

import Foundation
import FirebaseStorage

/** Create and upload a device data CSV file to Firebase Storage */
class FirebaseDeviceDataUploaderService {
    
    /** Create and upload a device data CSV file to Firebase Storage */
    static func upload(userId: String, deviceId: String, filename: String, fileExtension: String, contents: String) async {
        let rootRef = Storage.storage().reference()
        let fileName = "deviceData/\(userId)/\(deviceId)/\(filename).\(fileExtension)"
        let csvRef = rootRef.child(fileName)
        
        // Upload the file
        do {
            let _ = try await csvRef.putDataAsync(contents.data(using: .utf8)!)
            print("[File Management] Uploaded file to Firebase Storage at \"\(fileName)\"")
        } catch {
            print("[File Management] Firebase Storage upload failed with error:", error)
        }

    }

}
