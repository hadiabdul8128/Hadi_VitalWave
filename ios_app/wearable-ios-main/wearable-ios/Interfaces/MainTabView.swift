//
//  MainTabView.swift
//  wearable-ios
//
//  Created by Carola Maglione on 10/9/23.
//

import SwiftUI

/** The main TabView displayed in the application */
struct MainTabView: View {
    @State private var selectedTab = "Home"
    @StateObject private var bleModel = BLEModel()
    
    @ViewBuilder
    func Tab(_ title: String, systemImage: String, view: () -> some View) -> some View {
        view()
            .tabItem { Label(title, systemImage: systemImage) }
            .tag(title)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house") { HomeView().ignoresSafeArea() }
                Tab("Live", systemImage: "livephoto") { LiveDataView() }
                Tab("Self-Report", systemImage: "exclamationmark.bubble.fill") { WaypointsListView() }
                Tab("Devices", systemImage: "applewatch") { DevicesView() }
                Tab("Settings", systemImage: "gearshape.fill") { SettingsView() }
            }
        }.environmentObject(bleModel)
    }
}

#Preview {
    MainTabView().environmentObject(BLEModel())
    //MainTabView().environmentObject(NotificationModel())
   
}
