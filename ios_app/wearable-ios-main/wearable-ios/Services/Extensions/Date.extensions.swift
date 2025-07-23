//
//  Date.extensions.swift
//  wearable-ios
//
//  Created by Luke Redmore on 9/10/24.
//

import Foundation

extension Date {
    private static var isoMillisFormatter: DateFormatter {
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        isoFormatter.timeZone = .gmt
        return isoFormatter
    }
    
    static func fromISOMillisString(_ isoString: ISOMillisString) -> Date? {
        return isoMillisFormatter.date(from: isoString)
    }
    
    func toISOMillisString() -> String {
        return Date.isoMillisFormatter.string(from: self)
    }
}
