//
//  Notifications.extensions.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/29/24.
//

import Foundation

extension Notification {
    func asSample() -> (timestamp: Date, sample: SampleData)? {
        guard let timestampStr = self.userInfo?["timestamp"] as? ISOMillisString,
              let timestamp = Date.fromISOMillisString(timestampStr),
              let sample = self.userInfo?["sample"] as? SampleData else { return nil }
        return (timestamp, sample)
    }
}
