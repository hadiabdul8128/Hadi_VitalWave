//
//  LocalDeviceDataManagerService.swift
//  wearable-ios
//
//  Created by Luke Redmore on 2/20/24.
//

import SwiftUI

/** Fetch, load, and save data stored on device */
class LocalDeviceDataManagerService: ObservableObject {
    private let directoryUrl: URL
    @Published private(set) var documentUrls: [URL] = []
    
    init(uid: String, deviceId: String) {
        self.directoryUrl = URL.documentsDirectory
            .appendingPathComponent("deviceData")
            .appendingPathComponent(uid)
            .appendingPathComponent(deviceId)
        do {
            try FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true, attributes: nil)
            print("[File Management] Device data directoryUrl created at \"\(directoryUrl)\"")
        } catch {
            print("[File Management] Error creating directoryUrl: \(error)")
        }
    }
    
    /** Fetch and load URLs of locally saved data */
    func refresh() {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(
                at: directoryUrl,
                includingPropertiesForKeys: nil
            )
            documentUrls = directoryContents.sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
        } catch {
            print("[File Management] Could not list files for \(directoryUrl):", error)
            documentUrls = []
        }
    }
    
    func deleteFile(withUrl url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("[File Management] Successfully deleted file!")
            refresh()
        } catch {
            print("[File Management] Error deleting file: \(error)")
        }
    }
    
    func addFile(filename: String, fileExtension: String, contents: String) {
        do {
            let fileUrl = directoryUrl.appendingPathComponent("\(filename).\(fileExtension)")
            try contents.write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
            print("[File Management] Saved file to \"\(fileUrl)\"")
        } catch {
            print("[File Management] Local save failed with error:", error)
        }
        
        do {
            let directoryUrlForDate = directoryUrl
                .appendingPathComponent(String(filename.split(separator: "T")[0]))
            try FileManager.default.createDirectory(at: directoryUrlForDate, withIntermediateDirectories: true, attributes: nil)
            let fileUrlForDate = directoryUrlForDate.appendingPathComponent("\(filename).\(fileExtension)")
            try contents.write(to: fileUrlForDate, atomically: true, encoding: String.Encoding.utf8)
            print("[File Management] Saved file to \"\(fileUrlForDate)\"")
        } catch {
            print("[File Management] Error creating directoryUrl: \(error)")
        }
    }
    
}
