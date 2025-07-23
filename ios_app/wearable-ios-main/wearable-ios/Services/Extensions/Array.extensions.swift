//
//  Array.extensions.swift
//  wearable-ios
//
//  Created by Luke Redmore on 10/12/24.
//

import Foundation

extension Array {
    
    /// Calculates the value of the bound at the given percentile
    /// - Parameter percentile: The value of the percentile, out of 100
    /// - Parameter keyPath: A key path that specifies the property to compute the percentile on
    /// - Returns: The percentile value, or `0.0` if the array length is < 2 empty.
    func percentile<T: BinaryInteger>(_ percentile: Double, for path: KeyPath<Element, T>) -> Double {
        guard self.count > 1 else { return 0.0 }
        let data = self.sorted { $0[keyPath: path] < $1[keyPath: path] }
        let index = (percentile / 100) * Double(data.count - 1)
        let lowerIndex = Int(index)
        let fraction = index - Double(lowerIndex)
        if lowerIndex + 1 < data.count {
            let lowerVal = Double(data[lowerIndex][keyPath: path])
            let nextVal = Double(data[lowerIndex + 1][keyPath: path])
            return lowerVal + fraction * (nextVal - lowerVal)
        } else {
            return Double(data[lowerIndex][keyPath: path])
        }
    }
    
    /// Calculates the value of the bound at the given percentile
    /// - Parameter percentile: The value of the percentile, out of 100
    /// - Parameter keyPath: A key path that specifies the property to compute the percentile on
    /// - Returns: The percentile value, or `0.0` if the array length is < 2 empty.
    func percentile<T: BinaryFloatingPoint>(_ percentile: Double, for path: KeyPath<Element, T>) -> Double {
        guard self.count > 1 else { return 0.0 }
        let data = self.sorted { $0[keyPath: path] < $1[keyPath: path] }
        let index = (percentile / 100) * Double(data.count - 1)
        let lowerIndex = Int(index)
        let fraction = index - Double(lowerIndex)
        if lowerIndex + 1 < data.count {
            let lowerVal = Double(data[lowerIndex][keyPath: path])
            let nextVal = Double(data[lowerIndex + 1][keyPath: path])
            return lowerVal + fraction * (nextVal - lowerVal)
        } else {
            return Double(data[lowerIndex][keyPath: path])
        }
    }
    
    /// Calculates the mean value of the array over a given property using a key path.
    /// - Parameter keyPath: A key path that specifies the property to compute the mean.
    /// - Returns: The arithmetic mean value, or `0.0` if the array is empty.
    func arithmeticMean<T: BinaryInteger>(for keyPath: KeyPath<Element, T>) -> Double {
        guard !self.isEmpty else { return 0.0 }
        
        let total = self.reduce(0) { (result, element) -> T in
            result + element[keyPath: keyPath]
        }
        
        return Double(total) / Double(self.count)
    }

    /// Calculates the mean value of the array over a given property using a key path.
    /// - Parameter keyPath: A key path that specifies the property to compute the mean.
    /// - Returns: The arithmetic mean value, or `0.0` if the array is empty.
    func arithmeticMean<T: BinaryFloatingPoint>(for keyPath: KeyPath<Element, T>) -> Double {
        guard !self.isEmpty else { return 0.0 }
        
        let total = self.reduce(0) { (result, element) -> T in
            result + element[keyPath: keyPath]
        }
        
        return Double(total) / Double(self.count)
    }
    
    /// Calculates the standard deviation from the arithmetic of the array over a given property using a key path.
    /// - Parameter keyPath: A key path that specifies the property to compute the mean.
    /// - Parameter givenMean: The mean, if already computed, so as to not need to recompute
    /// - Returns: The standard deviation, or `0.0` if the array is empty.
    func standardDeviation<T: BinaryInteger>(for keyPath: KeyPath<Element, T>, givenMean upstreamMean: Double? = nil) -> Double {
        guard !self.isEmpty else { return 0.0 }
        
        let mean = upstreamMean ?? self.arithmeticMean(for: keyPath)
        let sumOfSquaredAvgDiff = self
            .map { el in
                let val = el[keyPath: keyPath]
                return pow(Double(val) - mean, 2.0)
            }
            .reduce(0.0) { $0 + $1 }
        return sqrt(sumOfSquaredAvgDiff / Double(self.count))
    }
    
    /// Calculates the standard deviation from the arithmetic of the array over a given property using a key path.
    /// - Parameter keyPath: A key path that specifies the property to compute the mean.
    /// - Returns: The standard deviation, or `0.0` if the array is empty.
    func standardDeviation<T: BinaryFloatingPoint>(for keyPath: KeyPath<Element, T>) -> Double {
        guard !self.isEmpty else { return 0.0 }
        
        let mean = self.arithmeticMean(for: keyPath)
        let sumOfSquaredAvgDiff = self
            .map { el in
                let val = el[keyPath: keyPath]
                return pow(Double(val) - mean, 2.0)
            }
            .reduce(0.0) { $0 + $1 }
        return sqrt(sumOfSquaredAvgDiff / Double(self.count))
    }
    
    /// Function to extract some range from an array. Returns empty array if `e > count` or `s >= e`
    func slice(s: Int, e: Int) -> [Element] {
        if e > self.count || s >= e {
            return []
        }
        return Array(self[s..<Swift.min(e, self.count)])
    }
}
