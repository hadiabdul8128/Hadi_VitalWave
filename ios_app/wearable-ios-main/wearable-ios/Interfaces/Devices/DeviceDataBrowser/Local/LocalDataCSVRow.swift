//
//  LocalDataCSVRow.swift
//  wearable-ios
//
//  Created by Luke Redmore on 2/20/24.
//

import SwiftUI
import QuickLook

/** The row itself for each CSV. Tapping on this row will display it to the user */
struct LocalDataCSVRow: View {
    let ref: LocalDataCSVRef
    @State private var showFileAtUrl: URL? = nil
    
    var body: some View {
        Button {
            showFileAtUrl = ref.fileUrl
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(ref.fileUrl.lastPathComponent)
                    Text("\(ref.startTime) local time").font(.caption).italic()
                }
            }
            
        }
        .buttonStyle(.plain)
        .quickLookPreview($showFileAtUrl)
    }
}
