//
//  WaypointsListView.swift
//  wearable-ios
//
//  Created by Luke Redmore on 9/7/24.
//

import SwiftUI

struct WaypointsListView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var waypointListener = WaypointListener()
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let waypoints = waypointListener.waypoints {
                        if waypoints.count <= 0 {
                            Text("No waypoints found")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(waypoints, id: \.self) { waypoint in
                                NavigationLink {
                                    SelfReportView(atDate: waypoint)
                                } label: {
                                    Text(waypoint.formatted(date: .abbreviated, time: .standard))
                                }
                            }
                        }
                    } else {
                        ProgressView()
                    }
                } header: {
                    Text("Recently Added")
                } footer: {
                    Text("Each row represents the date and time you pressed the waypoint button on the device. Tap any row to create a Self-Report at that time.")
                }
                Section {
                    NavigationLink {
                        SelfReportView()
                    } label: {
                        Text("Choose a different time...")
                    }
                }
            }
            .navigationTitle("Waypoints")
        }
        .onAppear {
            waypointListener.listen(uid: authViewModel.effectiveUid ?? "bypass-dev")
        }
        .onDisappear {
            waypointListener.stopListening()
        }
    }
}
