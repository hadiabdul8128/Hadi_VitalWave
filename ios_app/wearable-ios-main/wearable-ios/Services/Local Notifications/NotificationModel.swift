//
//  NotificationModel.swift
//  wearable-ios
//
//  Created by Jamee Krzanich on 9/10/24.
//

import Foundation
import UserNotifications

@MainActor class NotificationModel: NSObject, ObservableObject{
    static let shared = NotificationModel()
    let center = UNUserNotificationCenter.current()
    let options: UNAuthorizationOptions = [.alert, .sound]
    var requestIdentifiers: [String] = []
    var permissionGranted = false
    var notificationsEnabled: Bool {
        get{
            return UserDefaults.standard.bool(forKey: "debug-mode")
        }
    }
    /*var enableNotifications = false {
            didSet {
                if enableNotifications {
                    requestNotificationAuthorization()
                }
            }
        }*/
    
    override init() {
        super.init()
        requestNotificationAuthorization()
        
        
    }
    
    func cancelNotifications(){
        center.removeAllDeliveredNotifications()
    }
    
    func requestNotificationAuthorization() {
            center.requestAuthorization(options: options) { [weak self] (granted, error) in
                DispatchQueue.main.async {
                    if granted {
                        print("Notification permission granted.")
                        self?.permissionGranted = true
                    } else {
                        print("Notification permission denied.")
                        self?.permissionGranted = false
                    }
                    if let error = error {
                        print("Error requesting notification authorization: \(error.localizedDescription)")
                    }
                }
            }
        }
    public func createNotification() {
        if notificationsEnabled && permissionGranted {
            print("this is the current debugmode val: \(notificationsEnabled)")
            let content = UNMutableNotificationContent()
            content.title = "BLE Connectivity"
            content.subtitle = "BLE is not connected"
            content.sound = UNNotificationSound.default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)  // Increased to 60 seconds
            let identifier = "bleConnectivityNotification"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("Error adding notification: \(error.localizedDescription)")
                } else {
                    print("Notification scheduled with identifier: \(identifier)")
                }
            }
        }
    }
        
    
    
}
