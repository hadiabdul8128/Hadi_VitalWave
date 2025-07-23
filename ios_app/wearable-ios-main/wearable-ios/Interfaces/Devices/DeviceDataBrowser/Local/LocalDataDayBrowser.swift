//
//  LocalDataDayBrowser.swift
//  wearable-ios
//
//  Created by Luke Redmore on 2/20/24.
//

import SwiftUI
import QuickLook

struct LocalDataCSVRef {
    let startTime: String
    let fileUrl: URL
}

/** Used as the detail view for each date of data collected. Displays a `List` containing all the CSVs fetched for that day */
struct LocalDataDayBrowser: View {
    let dateString: String
    let csvRefs: [LocalDataCSVRef]
    let onFileDelete: (_ url: URL) -> Void
    
    var body: some View {
        List {
            Section {
                ForEach(csvRefs, id:\.fileUrl.lastPathComponent) { ref in
                    LocalDataCSVRow(ref: ref)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onFileDelete(ref.fileUrl)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
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
