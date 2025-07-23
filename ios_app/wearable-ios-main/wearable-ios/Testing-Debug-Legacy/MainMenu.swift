//
//  MainMenu.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/12/23.
//

import SwiftUI

/** The dropdown menu to access various views in the app. This is currently unused because all the views it accesses are also accessible in the `MainTabView` */
struct MainMenu: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let onMenuItemPress: ((String) -> Void)?
    
    @ViewBuilder
    func MenuItem(_ title: String, systemImage: String) -> some View {
        Button {
            onMenuItemPress?(title)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
    
    var body: some View {
        Menu {
            MenuItem("Home", systemImage: "house")
            #if DEBUG
            MenuItem("Help", systemImage: "questionmark.app.fill")
            #endif
            MenuItem("Live", systemImage: "livephoto")
            MenuItem("Self-Report", systemImage: "exclamationmark.bubble.fill")
            MenuItem("Devices", systemImage: "applewatch")
            MenuItem("Settings", systemImage: "gearshape.fill")
        } label: {
            Circle()
                .fill(.gray.opacity(0.15))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 13.0, weight: .semibold))
                        .imageScale(.large)
                        .foregroundColor(Color("ThemeBlue"))
                }
                .padding()
                .padding(.top, -15.0)
            
        }
    }
}

#Preview {
    MainMenu(onMenuItemPress: nil)
}
