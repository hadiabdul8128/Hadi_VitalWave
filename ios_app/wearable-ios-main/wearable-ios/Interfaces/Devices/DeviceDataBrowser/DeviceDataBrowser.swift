//
//  DeviceDataBrowser.swift
//  wearable-ios
//
//  Created by Luke Redmore on 11/20/23.
//

import SwiftUI

/** This struct kicks of displaying device data by querying all CSVs for the given `deviceId` and `uid`.
 It groups them by (local) date and displays each date where data was collected in a `List` */
struct DeviceDataBrowser: View {
    @StateObject private var fbService: QueryStorageDirectoryService
    @StateObject private var localService: LocalDeviceDataManagerService
    
    /** Computed var from fetched files that groups them by date */
    private var cloudFilesByDate: [String:[FirebaseDataCSVRef]] {
        var toReturn: [String:[FirebaseDataCSVRef]] = [:]
        fbService.files?.forEach { file in
            if let date = Date.fromISOMillisString(file.name.replacingOccurrences(of: ".csv", with: "")) {
                let dateString = date.formatted(date: .numeric, time: .omitted)
                let timeString = date.formatted(date: .omitted, time: .standard)
                var row = toReturn[dateString] ?? []
                row.append(FirebaseDataCSVRef(
                    startTime: timeString,
                    file: file
                ))
                toReturn[dateString] = row
            }
        }
        return toReturn
    }
    
    /** Computed var from fetched files that groups them by date */
    private var localFilesByDate: [String:[LocalDataCSVRef]] {
        var toReturn: [String:[LocalDataCSVRef]] = [:]
        localService.documentUrls.forEach { url in
            if let date = Date.fromISOMillisString(url.lastPathComponent.replacingOccurrences(of: ".csv", with: "")) {
                let dateString = date.formatted(date: .numeric, time: .omitted)
                let timeString = date.formatted(date: .omitted, time: .standard)
                var row = toReturn[dateString] ?? []
                row.append(LocalDataCSVRef(
                    startTime: timeString,
                    fileUrl: url
                ))
                toReturn[dateString] = row
            }
        }
        return toReturn
    }
    
    init(uid: String, deviceId: String) {
        _fbService = StateObject(wrappedValue: QueryStorageDirectoryService(path: "deviceData/\(uid)/\(deviceId)"))
        _localService = StateObject(wrappedValue: LocalDeviceDataManagerService(uid: uid, deviceId: deviceId))
    }
    
    var body: some View {
        List {
            Section {
                ForEach(cloudFilesByDate.sorted(by: { $0.key > $1.key }), id: \.key) { key, val in
                    NavigationLink {
                        CloudDataDayBrowser(dateString: key, csvRefs: val)
                    } label: {
                        HStack {
                            Text(key)
                            Spacer()
                            Text("\(val.count) files").font(.caption)
                        }
                    }
                }
                
                if !fbService.allDataLoaded {
                    Button("Load More") {
                        fbService.loadNextPage()
                    }
                }
            } header: {
                Text("Stored in cloud")
            } footer: {
                Text("The above files are organized according to the local time zone, but are titled using the equivalent UTC timestamps when exported")
            }
            Section {
                ForEach(localFilesByDate.sorted(by: { $0.key > $1.key }), id: \.key) { key, val in
                    NavigationLink {
                        LocalDataDayBrowser(dateString: key, csvRefs: val, onFileDelete: localService.deleteFile)
                    } label: {
                        HStack {
                            Text(key)
                            Spacer()
                            Text("\(val.count) files").font(.caption)
                        }
                    }
                }
            } header: {
                Text("Stored locally")
            }
            
        }
        .refreshable {
            fbService.refresh()
            localService.refresh()
        }
        .onAppear {
            fbService.loadNextPage()
            localService.refresh()
        }
        .navigationTitle("Data Collected")
    }
}

#Preview {
    DeviceDataBrowser(uid: "", deviceId: "")
}
