//
//  QueryStorageDirectoryService.swift
//  wearable-ios
//
//  Created by Luke Redmore on 11/20/23.
//

import Foundation
import FirebaseStorage

/** This class provides stateful variables to lazily-load list data in FirebaseStorage at the provided `path`.
 * KNOWN ISSUE: No way to query only a subset of a directory, must start from the very beginning. */
class QueryStorageDirectoryService: ObservableObject {
    private static let PAGE_SIZE: Int64 = 100
    
    private let dataDirectory: StorageReference
    private var pageToken: String? = nil
    
    @Published private(set) var files: [StorageReference]? = nil
    @Published private(set) var allDataLoaded = false
    
    init(path: String) {
        self.dataDirectory = Storage.storage().reference().child(path)
    }
    
    func loadNextPage() {
        guard !allDataLoaded else {
            print("All data already loaded!")
            return
        }
        if let pageToken = pageToken {
            dataDirectory.list(maxResults: QueryStorageDirectoryService.PAGE_SIZE, pageToken: pageToken, completion: onDataLoaded)
        } else {
            dataDirectory.list(maxResults: QueryStorageDirectoryService.PAGE_SIZE, completion: onDataLoaded)
        }
    }
    
    func refresh() {
        pageToken = nil
        files = nil
        allDataLoaded = false
        loadNextPage()
    }
    
    private func onDataLoaded(result: Result<StorageListResult, any Error>) -> Void {
        switch result {
        case .success(let data):
            if files == nil { files = [] }
            files?.append(contentsOf: data.items)
            
            if let newToken = data.pageToken {
                self.allDataLoaded = false
                self.pageToken = newToken
                self.loadNextPage()
            } else {
                self.allDataLoaded = true
            }
        case .failure(let error):
            print("Failed to load data: \(error)")
        }
    }
}
