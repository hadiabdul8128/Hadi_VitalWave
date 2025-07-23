//
//  WaypointListener.swift
//  wearable-ios
//
//  Created by Luke Redmore on 9/7/24.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

/** Listen for changes under Firestore/waypoints after .listen() is called */
class WaypointListener: ObservableObject {
    @Published var waypoints: [Date]?
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration? = nil
        
    func listen(uid: String) {
        print("[WaypointListener] Attaching listener for \(uid)")
        self.listener = db.collection("waypoints")
            .whereField("uid", isEqualTo: uid)
            .order(by: "time", descending: true)
            .limit(to: 10)
            .addSnapshotListener { (querySnapshot, error) in
                guard let docs = querySnapshot?.documents else {
                    print("[WaypointListener] Received empty snapshot for \(uid)")
                    if let error = error {
                        print("[WaypointListener] Snapshot listener for \(uid) returned error:", error)
                    }
                    self.waypoints = nil
                    return
                }
                print("[WaypointListener] Received snapshot for \(uid) with \(docs.count) docs")
                self.waypoints = []
                for doc in docs {
                    let data = doc.data()
                    if let dateString = data["time"] as? String, let date = Date.fromISOMillisString(dateString) {
                        print("[WaypointListener] Found time", date)
                        self.waypoints?.append(date)
                    } else {
                        print("[WaypointListener] Could not find time in doc", doc)
                    }
                }
            }
    }
    
    func stopListening() {
        self.listener?.remove()
    }
}

