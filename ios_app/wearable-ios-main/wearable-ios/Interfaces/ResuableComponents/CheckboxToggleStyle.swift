//
//  CheckboxToggleStyle.swift
//  wearable-ios
//
//  Created by Aseda Asomani on 10/24/23.
//

import Foundation
import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
 
            RoundedRectangle(cornerRadius: 5.0)
                .stroke(lineWidth: 5)
                .frame(width: 25, height: 25)
                .cornerRadius(5.0)
                .overlay {
                    Image(systemName: configuration.isOn ? "checkmark" : "square")
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

//enum reportCategory {
//    case exercise
//    case fear
//    case excitement
//    case externalTemp
//    case stress
//    case drugs //caffeine, medicine, narcotics, etc.
//    case illness
//    case chronic //for illnesses a person may have been born with or developed whose symptoms change physiological factors
//}
