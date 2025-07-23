//
//  APIManager.swift
//  wearable-ios
//
//  Created by Luke Redmore on 4/19/24.
//

import Foundation

class APIManager {
    
    // Send request
    static func sendRequest<T: Codable, U: Codable>(method: String, url: String, parameters: T) async ->  (Result<U, Error>)  {
        guard let url = URL(string: url) else {
            return .failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        //        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")
        
        if method == "POST" || method == "PUT" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONEncoder().encode(parameters)
            } catch {
                return .failure(error)
            }
        }
        
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let _ = response as? HTTPURLResponse else {
                return .failure(NSError(domain: "Invalid response", code: 0, userInfo: nil))
            }
            
            //                if httpResponse.statusCode == 401 {
            //                    try await refreshToken()
            //                    try await sendRequest(method: method, endpoint: endpoint, parameters: parameters, completion: completion)
            //                } else {
            
            switch U.self {
            case is String.Type:
                let str = String(data: data, encoding: .utf8)
                assert(str != nil)
                return .success(str as! U)
            default:
                let decodedResponse = try JSONDecoder().decode(U.self, from: data)
                return .success(decodedResponse)
            }
        } catch {
            return .failure(error)
        }
        
    }
}
