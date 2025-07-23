//
//  CloudDataCSVRow.swift
//  wearable-ios
//
//  Created by Luke Redmore on 2/20/24.
//

import SwiftUI

/** The row itself for each CSV. Tapping on this row will download the associated file to a temporary directory where it is then displayed to the user */
struct CloudDataCSVRow: View {
    let ref: FirebaseDataCSVRef
    @State private var downloadURL: URL? = nil
    @State private var isDownloading = false
    
    var body: some View {
        Button {
            isDownloading = true
            let tempUrl = FileManager.default.temporaryDirectory
                .appendingPathComponent(ref.file.name.replacingOccurrences(of: ":", with: "."))
            ref.file.write(toFile: tempUrl) { downloadedUrl, error in
                if let error = error {
                    print(error)
                    return
                }
                downloadURL = downloadedUrl
                isDownloading = false
            }
            
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(ref.file.name)
                    Text("\(ref.startTime) local time").font(.caption).italic()
                }
                if isDownloading {
                    Spacer()
                    ProgressView()
                }
            }
            
        }
        .buttonStyle(.plain)
        .quickLookPreview($downloadURL)
    }
}
