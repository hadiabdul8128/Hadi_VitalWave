//
//  CloudDataDayBrowser.swift
//  wearable-ios
//
//  Created by Luke Redmore on 2/20/24.
//

import SwiftUI
import FirebaseStorage
import QuickLook

struct FirebaseDataCSVRef {
    let startTime: String
    let file: StorageReference
}

/** Used as the detail view for each date of data collected. Displays a `List` containing all the CSVs fetched for that day */
struct CloudDataDayBrowser: View {
    let dateString: String
    let csvRefs: [FirebaseDataCSVRef]
    
    var body: some View {
        List {
            Section {
                ForEach(csvRefs, id:\.file.name) { ref in
                    CloudDataCSVRow(ref: ref)
                }
            } header: {
                Text("Each row represents a CSV file containing data collected beginning at the titular time. Tap on any row to preview or export it.")
                    .textCase(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom)
            }
            
        }.navigationTitle(dateString)
    }
}
