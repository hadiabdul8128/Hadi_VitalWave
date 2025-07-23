//
//  IncomingDataBuffer.swift
//  wearable-ios
//
//  Created by Luke Redmore on 11/16/23.
//

import Foundation
import FirebaseCore
import FirebaseFirestore


/** This class aggregates incoming, unsaved wearable data into SampleData objects by timestamp, merging them if a row already exists for that timestamp.
 *  It also uploads waypoint and battery info directly to Firestore and uploads each row CSV to Firebase Storage when it reaches the maximum size */
class IncomingDataBuffer {
    
    private var MAX_BUFFER_SIZE_BYTES = 5000000 // 1_048_576 // 1 MB
    private var debugMode: Bool { UserDefaults.standard.bool(forKey: "debug-mode") }
    private let deviceId: String
    private let uid = UserDefaults.standard.string(forKey: "auth-uid")!
    private let db = Firestore.firestore()
    private let localService: LocalDeviceDataManagerService
    private var firstDataReceived = true
    private let mostRecentRow = SampleData()
    private var batteryBuffer: UInt8 = 101 // Holds the battery level from previous sample here so we only update Firebase when it changes
    private var fileURL: URL
    private var currentFileName: String = ""
   

        
    init(deviceId: String) {
        self.deviceId = deviceId
        self.localService = LocalDeviceDataManagerService(uid: uid, deviceId: deviceId)
        self.fileURL = URL.documentsDirectory
            .appendingPathComponent("deviceData")
            .appendingPathComponent(uid)
            .appendingPathComponent(deviceId)
        
    }
    
    /** Add data from a received packet to the buffer */
    func append(_ packet: IncomingWearablePacket) {
        
        print("Received and decoded packet with \(packet.samples.count) samples, adding to buffer")
        for (timestamp, sampleData) in packet.samples {
            
            var fileSize : UInt64
            
            if(!firstDataReceived){
                do {
                    //return [FileAttributeKey : Any]
                    let newLine = "\(timestamp),"+sampleData.csvString + "\n"
                    let attr = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    fileSize = attr[FileAttributeKey.size] as! UInt64
                    
                    if let connectedPeriph = PairedPeripheralManager.pairedPeripheralWithId(deviceId: deviceId){
                        MAX_BUFFER_SIZE_BYTES = connectedPeriph.counter 
                    }
                    if(fileSize < (debugMode ? 50000 : MAX_BUFFER_SIZE_BYTES)){
                        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                            fileHandle.seekToEndOfFile()
                            
                            if let csvData = newLine.data(using: .utf8) {
                                print("this is the data going to csv: \(timestamp),\(newLine)")
                                fileHandle.write(csvData)
                            } else {
                                print("Failed to convert sampleData to Data format.")
                            }
                            fileHandle.closeFile()
                        } else {
                            print("Unable to open file for writing.")
                        }
                    }else{
                        uploadToFirestore(url: fileURL)
                        firstDataReceived = true
                    }
                    
                } catch {
                    print("[CSV] Error: \(error)")
                }
                
            }
            
            if (firstDataReceived){
                self.fileURL = URL.documentsDirectory
                    .appendingPathComponent("deviceData")
                    .appendingPathComponent(uid)
                    .appendingPathComponent(deviceId)
                    .appendingPathComponent("\(timestamp).csv")
                self.currentFileName = "\(timestamp)"
                let columnHeaders = "isodate,\(SampleData.CSV_COLUMN_ORDER.joined(separator: ","))"
                let csvDataString = columnHeaders + "\n"
                
                if let csvData = csvDataString.data(using: .utf8) {
                    do {
                            
                            
                            try csvData.write(to: fileURL)
                            
                            
                            print("CSV file written successfully!")
                            firstDataReceived = false
                        } catch {
                            print("Failed to write CSV file: \(error), \(csvDataString), \(csvData)")
                        }
                        
                }else{
                    print("Failed to convert CSV string to Data format.")
                }
                
            }
            
            // Upload directly to firestore if we get a waypoint or battery level
            if sampleData.waypoints == 1 || (debugMode && Int(Date().timeIntervalSince1970) % 10 == 5)  {
                Task {
                    do {
                        let ref = try await db.collection("waypoints").addDocument(data: ["time": timestamp, "uid": uid])
                        print("[CSV]\t\tWaypoint added to firestore with ID: \(ref.documentID)")
                    } catch {
                        print("[CSV]\t\tError adding waypoint to Firestore: \(error)")
                    }
                }
            }
            
            if let battery = sampleData.battery, batteryBuffer != battery {
                Task {
                    do {
                        try await db.collection("devices").document(deviceId).updateData(["battery": battery])
                        batteryBuffer = battery
                        print("[CSV]\t\tUpdated battery level to \(battery) for device \(deviceId) on Firestore")
                    } catch {
                        print("[CSV]\t\tFailed to updated battery level to \(battery) for device \(deviceId) on Firestore: \(error)")
                    }
                }
            }
        }
        
        
    }
    
    /** TODO: Once toggle is set to cloud (or internet connection resumed) check buffer for saved data and upload the packets if it has anything */
    private func uploadToFirestore(url: URL) {
        Task {
            /** TODOS: Check to see if there is an internet connection */
            /** Cloud storage resumable upload */
            
            let fileExtension = "csv"
            
            if let connectedPeriph = PairedPeripheralManager.pairedPeripheralWithId(deviceId: deviceId) {
                if (connectedPeriph.saveToCloud && connectedPeriph.saveToDisk) {
                    print("[CSV] uploadToFirestore - Saving to both cloud and disk")
                    let fileContents = try String(contentsOf: url, encoding: .utf8)
                    
                    await FirebaseDeviceDataUploaderService.upload(userId: uid, deviceId: deviceId, filename: currentFileName, fileExtension: fileExtension, contents: fileContents)
                    print("[CSV] uploadToFirestore - Uploaded to firestore as \(currentFileName)")
                }else if (connectedPeriph.saveToCloud){
                    print("[CSV] uploadToFirestore - Saving to both cloud")
                    let fileContents = try String(contentsOf: url, encoding: .utf8)
                    
                    await FirebaseDeviceDataUploaderService.upload(userId: uid, deviceId: deviceId, filename: currentFileName, fileExtension: fileExtension, contents: fileContents)
                    print("[CSV] uploadToFirestore - Uploaded to firestore as \(currentFileName)")
                
                    do {
                        let fileManager = FileManager.default
                        if fileManager.fileExists(atPath: url.path()) {
                            try fileManager.removeItem(at: url)
                            print("[CSV] uploadToFirestore File deleted successfully.")
                        } else {
                            print("[CSV] uploadToFirestore File does not exist at path: \(url.path)")
                        }
                    } catch {
                        print("[CSV] uploadToFirestore Error deleting file: \(error.localizedDescription)")
                    }
                } else {
                    print("[CSV] uploadToFirestore - Saving to both disk")
                    
                }
                
            } else {
                print("[CSV] Not saving data, no device found!")
            }
        }
    }
}
