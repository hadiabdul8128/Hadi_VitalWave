//
//  SelfReportView.swift
//  wearable-ios
//
//  Created by Aseda Asomani on 10/3/23.
//

import Foundation
import SwiftUI
import os

// Popup tab telling user how to use the self report rather than putting it on page. Pops up every time the page is opened

/** View allowing users to create and upload a Self-Report*/
struct SelfReportView: View {
    @EnvironmentObject private var authModel: AuthViewModel
    @EnvironmentObject private var bleModel: BLEModel
    @State private var report: String = ""
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var interval = false
    @State private var selectedCategory: reportCategory?
    @State private var categoryNum: String = "0 none"
    @State private var alert = false
    @State private var errText: String?
    @State private var deviceId: String = ""
    
    var localTimeZoneAbbreviation: String { return TimeZone.current.abbreviation() ?? "" }
    var localTimeZoneIdentifier: String { return TimeZone.current.identifier }
    
    func clearForm() {
        report = ""
        date = Date()
        startTime = Date()
        endTime = Date()
        interval = false
        selectedCategory = nil
        categoryNum = "0 none"
    }
    
    init(atDate date: Date? = nil) {
        if var date = date {
            _date = State(initialValue: date)
            _startTime = State(initialValue: date)
            date.addTimeInterval(15*60)
            _endTime = State(initialValue: date)
        } else {
            _date = State(initialValue: Date())
            _startTime = State(initialValue: Date())
            _endTime = State(initialValue: Date())
        }
    }
    
    var body: some View {
        let dateRange: ClosedRange<Date> = {
            let calendar = Calendar.current
            let year = Calendar(identifier: .gregorian).dateComponents([.year], from: .now).year
            let startComponents = DateComponents(year: year, month: 1, day: 1)
            let endComponents = DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59, second: 59)
            return calendar.date(from:startComponents)!
            ...
            calendar.date(from:endComponents)!
        }()
        
        NavigationStack{
            if bleModel.pairedPeripheralManager.peripherals.isEmpty {
                Text("Please add a device (under \"Devices\") in order to fill out a self-report").multilineTextAlignment(.center)
                    .padding()
                    .navigationTitle("Self-Report")
            } else {
                Form {
                    Picker("Select a device", selection: $deviceId) {
                        if deviceId == "" {
                            Text("Select...").tag("")
                        }
                        ForEach(bleModel.pairedPeripheralManager.peripherals, id: \.id) {
                            Text($0.name).tag($0.id)
                        }
                        .pickerStyle(.menu)
                    }
                    Text("Please explain below all activities or circumstances that may cause a drastic change in blood pressure, temperature, and other bodily feaures measured by the device such as exercise, carnival rides, etc.")
                    Toggle(isOn: $interval){
                        Text("Please select if you need to enter a time interval")
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    DatePicker("Report Date", selection: $date, in: dateRange, displayedComponents: .date)
                    DatePicker("Report Time", selection: $date, displayedComponents: [.hourAndMinute])
                    //                            .labelsHidden()
                    if interval == true {
                        DatePicker("Start Time", selection: $startTime, in: ...Date.now, displayedComponents: .hourAndMinute)
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                    TextField("Enter report here...", text: $report)
                    ForEach(reportCategory.allCases, id: \.self) { category in
                        Toggle(category.rawValue, isOn: Binding(
                            get: { self.selectedCategory == category },
                            set: { newValue in
                                if newValue {
                                    self.selectedCategory = category
                                } else {
                                    self.selectedCategory = nil
                                }
                            }
                        ))
                        .toggleStyle(RadioButtonStyle())
                    }
                    Button ("Submit") {
                        Task {
                            guard let uid = authModel.user?.uid else {
                                errText = "No user logged in!"
                                alert = true
                                return
                            }
                            guard deviceId != "" else {
                                errText = "Please select the device you were using!"
                                alert = true
                                return
                            }
                            switch selectedCategory{
                            case .exercise:
                                categoryNum = "1 exercise"
                            case .fear:
                                categoryNum = "2 fear"
                            case .excitement:
                                categoryNum = "3 excitement"
                            case .externalTemp:
                                categoryNum = "4 external-temperature"
                            case .stress:
                                categoryNum = "5 stress"
                            case .drugs:
                                categoryNum = "6 drugs"
                            case .illness:
                                categoryNum = "7 illness"
                            case .chronic:
                                categoryNum = "8 chronic-illness"
                            default:
                                categoryNum = "0 none"
                            }
                            
                            do {
                                try await ReportUploaderService.upload(userId: uid, deviceId: deviceId, date: date, startTime: startTime, endTime: endTime, interval: interval, category: categoryNum, report: report)
                                errText = nil
                                alert = true
                                clearForm()
                            } catch {
                                print("Error uploading CSV: \(error)")
                                errText = error.localizedDescription
                                alert = true
                            }
                            
                        }
                    }
                    .alert(isPresented: $alert, content: {
                        if let errorText = errText {
                            Alert(title: Text("Failed to submit report"), message: Text(errorText), dismissButton: .default(Text("Close")))
                        } else {
                            Alert(title: Text("Report Status"), message: Text("Your response has been uploaded."), dismissButton: .default(Text("Close")))
                            
                        }
                    })
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .navigationTitle("Self-Report")
            }
        }.onAppear {
            // Clear selected device if not in paired devices
            if !bleModel.pairedPeripheralManager.peripherals.contains(where: { $0.id == deviceId}) { // paired devices doesn't contain this device anymore
                deviceId = ""
            }
            
            // If paired devices has only one choice, set it to that
            if bleModel.pairedPeripheralManager.peripherals.count == 1 && deviceId == "" {
                deviceId = bleModel.pairedPeripheralManager.peripherals[0].id
            }
        }
    }
    //    if reportCategory.exercise {
    //        category = 1
    //    }
}




func encodeStringToBase64(_ inputString: String) -> String? {
    if let inputData = inputString.data(using: .utf8) {
        let base64String = inputData.base64EncodedString()
        return base64String
    }
    return nil
}


#Preview {
    SelfReportView()
}
