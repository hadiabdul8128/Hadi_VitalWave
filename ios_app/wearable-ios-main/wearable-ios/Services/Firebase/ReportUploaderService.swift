//
//  ReportUploaderService.swift
//  wearable-ios
//
//  Created by Aseda Asomani on 10/24/23.
//

import Foundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseCore

/** Upload a self-report to Firebase storage */
class ReportUploaderService {
    
    /** Upload a self-report to Firebase storage */
    static func upload(userId: String, deviceId: String, date: Date, startTime: Date?, endTime: Date?, interval: Bool, category: String, report: String) async throws {
        // Create a root reference
        let rootRef = Storage.storage().reference()
//        let db = Firestore.firestore()
        
        // Create a reference to "mountains.jpg"
        let dateString = date.ISO8601Format()
        let fileName = "reportData/\(userId)/\(deviceId)/\(dateString).csv"
        let csvRef = rootRef.child(fileName)
        let dataString: String

        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm E; d MMM y"
        print(dateFormatter.string(from: date))
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .medium

        let reportEncoded = report.data(using: .utf8)?.base64EncodedString() ?? report
        
            if let start = startTime, let end = endTime {
                dataString = "Category,Report Submission Date,Interval,StartTime,EndTime,Report\n\(category),\(date.ISO8601Format(.iso8601(timeZone: .gmt)))Z,\(interval),\(start.ISO8601Format(.iso8601(timeZone: .gmt)))Z,\(end.ISO8601Format(.iso8601(timeZone: .gmt)))Z,\(reportEncoded)"
            } else {
                dataString = "Category,Report Submission Date,Interval,StartTime,EndTime,Report\n\(category),\(date.ISO8601Format(.iso8601(timeZone: .gmt)))Z,\(interval),null,null,\(reportEncoded)"
            }
        
        
        // Upload the file
        do {
            let _ = try await csvRef.putDataAsync(dataString.data(using: .utf8)!)
            print("[CSV] Uploaded \(report.count) rows to \"\(fileName)\"")
        } catch {
            print(error)
            throw UploadError.uploadFailed
        }
        
        let db = Firestore.firestore()
        do {
            
                var data: [String: Any] = [
                    "userId": userId,
                    "deviceId": deviceId,
                    "date": "\(date.ISO8601Format(.iso8601(timeZone: .gmt)))Z",
                    "interval": interval,
                    "category": category,
                    "report": report
                ]
            
            if let start = startTime {
                data["startTime"] = "\(start.ISO8601Format(.iso8601(timeZone: .gmt)))Z"
            }
            if let end = endTime {
                data["startTime"] = "\(end.ISO8601Format(.iso8601(timeZone: .gmt)))Z"
            }
            try await db.collection("report_data").addDocument(data: data)
          print("Self Report Document successfully written!")
        } catch {
          print("Error writing document: \(error)")
        }
    
        enum UploadError: Error {
            case invalidData
            case uploadFailed
        }
    /** Converts the given `unixSeconds` to the following formated string:  `"yyyy-MM-ddTHH:mm:ss.SSSZ"`*/
    func fixDate(unixSeconds: Double) -> String {
        let date = Date(timeIntervalSince1970: unixSeconds)
        let extraMillis = String(format: "%.3f", unixSeconds).suffix(3)
        return "\(date.ISO8601Format(.iso8601(timeZone: .gmt))).\(extraMillis)Z"
    }
//        db.collection("User").document("Report").setData([
//            "date": date,
//            "startTime": startTime,
//            "endTime": endTime,
//            "interval": interval,
//            "category": category,
//            "report": report
//        ]) { err in
//            if let err = err {
//                print("Error writing document: \(err)")
//            } else {
//                print("Document successfully written!")
//            }
//        }
    }
    
}
