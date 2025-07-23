//
//  Settings.swift
//  wearable-ios
//
//  Created by Aseda Asomani on 10/3/23.
//

import Foundation
import SwiftUI
import os

struct SettingsView: View {
    @EnvironmentObject private var authModel: AuthViewModel
    @AppStorage("debug-mode") public var debugMode : Bool = false
    
    
    var version: String {
        guard let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        else {
            return "N/A"
        }
        return "\(appVersion) (\(buildNumber))"
    }
    
    var body: some View {
        NavigationStack {
            List {
                if let user = authModel.user {
                    Section("Account") {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email ?? "")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("UID")
                            Spacer()
                            Text(user.uid)
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }
                    }
                }
                Section {
                    
                    if debugMode {
                        
                        NavigationLink {
                            MenuTestView()
                        } label: {
                            Label("Menu Test", systemImage: "line.3.horizontal")
                        }
                        NavigationLink {
                            BluetoothTestView()
                        } label: {
                            Label("BLE Test", systemImage: "app.connected.to.app.below.fill")
                        }
                        NavigationLink {
                            HelpView()
                        } label: {
                            Label("Help [WIP]", systemImage: "questionmark.app")
                        }
                       
                        
                    }
                    Toggle("Enabled", isOn: $debugMode)
                       /* .onChange(of: debugMode, { oldValue, newValue in
                            NotificationModel.shared.notificationsEnabled = newValue
                            print("Notification model changed to \(newValue)")
                        })*/
                        
                        
                }  header: {
                    Text("Debug Mode")
                } footer: {
                    Text("When enabled, Debug Mode provides some extra screens used for testing")
                }

                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text(version)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        authModel.signOut()
                    } label: {
                        Text("Sign Out")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                }
            }.navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        
}
