//
//  RadioButtonStyle.swift
//  wearable-ios
//
//  Created by Aseda Asomani on 11/9/23.
//

import Foundation
import SwiftUI

struct RadioButtonStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
 
            Circle()
                .stroke(lineWidth: 3)
                .frame(width: 25, height: 25)
                .overlay {
                    Image(systemName: configuration.isOn ? "largecircle.fill.circle" : "circle")
                }
                .onTapGesture {
                    withAnimation(.spring()) {
                        configuration.isOn.toggle()
                    }
                }
 
            configuration.label
 
        }
    }
}

enum reportCategory: String, CaseIterable {
    case exercise = "Exercise"
    case fear = "Fear"
    case excitement  = "Excitement"
    case externalTemp = "External Temperature"
    case stress = "Stress"
    case drugs = "Drugs (caffeine, medicine, narcotics, etc.)" //caffeine, medicine, narcotics, etc.
    case illness = "Illness"
    case chronic = "Chronic Illness" //for illnesses a person may have been born with or developed whose symptoms change physiological factors
}
