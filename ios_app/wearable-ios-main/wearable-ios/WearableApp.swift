//
//  wearable_iosApp.swift
//  wearable-ios
//
//  Created by Luke Redmore on 9/18/23.
//

import SwiftUI
import FirebaseCore

/** An AppDelegate is necessary to initialize Firebase on app launch */
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct WearableApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            AuthDeciderView()
        }
    }
}

