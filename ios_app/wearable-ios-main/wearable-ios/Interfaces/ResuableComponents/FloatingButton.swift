//
//  FloatingButton.swift
//  wearable-ios
//
//  Created by Luke Redmore on 11/14/23.
//

import SwiftUI

struct FloatingButton: View {
    let action: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: action) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(radius: 5)
            }
        }.padding()
    }
}

#Preview {
    FloatingButton() {}
}
