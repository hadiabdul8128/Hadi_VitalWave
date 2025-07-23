//
//  Data.extensions.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/19/23.
//

import Foundation

/** This file is just extensions to the `Data` class  to make decoding value in received binary data easier */
extension Data {
    
    private static let hexAlphabet = Array("0123456789ABCDEF".unicodeScalars)
    public func asHexString() -> String {
        String(reduce(into: "".unicodeScalars) { result, value in
            result.append(Self.hexAlphabet[Int(value / 0x10)])
            result.append(Self.hexAlphabet[Int(value % 0x10)])
        })
    }
    
    var uint8: UInt8 { withUnsafeBytes({ $0.load(as: UInt8.self) }) }
    
    var float32: Float32 {
        return withUnsafeBytes {
            let floatPointer = $0.baseAddress!.assumingMemoryBound(to: Float32.self)
            return floatPointer.pointee
        }
    }
    
    var float32Little: Float32 {
        let reversedData = Data(self.reversed())
        return reversedData.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> Float32 in
            let floatPointer = pointer.baseAddress!.assumingMemoryBound(to: Float32.self)
            return floatPointer.pointee
        }
    }
    
    var uint32Little: UInt32 {
        let reversedData = Data(self.reversed())
        return reversedData.withUnsafeBytes {
            let floatPointer = $0.baseAddress!.assumingMemoryBound(to: UInt32.self)
            return floatPointer.pointee
        }
    }
    
    var uint32: UInt32 {
        return withUnsafeBytes {
            let floatPointer = $0.baseAddress!.assumingMemoryBound(to: UInt32.self)
            return floatPointer.pointee
        }
    }
    
    var uint16: UInt16 {
        return withUnsafeBytes {
            let floatPointer = $0.baseAddress!.assumingMemoryBound(to: UInt16.self)
            return floatPointer.pointee
        }
    }
}

extension Int {
    
    /// Optionally cast Double? to Int?
    init?(_ double: Double?) {
        guard let double = double, double.isFinite, double.isNaN == false else { return nil }
        self.self = Int(double)
    }
}

extension Float32 {
    
    /// Optionally cast Double? to Float32?
    init?(_ double: Double?) {
        guard let double = double, double.isFinite, double.isNaN == false else { return nil }
        self.self = Float32(double)
    }
}
