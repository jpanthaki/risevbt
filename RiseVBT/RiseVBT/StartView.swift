//
//  StartView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/2/25.
//

import SwiftUI

struct StartView: View {
    var body: some View {
        ZStack{
            Color.blue.opacity(0.5)
                .ignoresSafeArea()
            VStack {
                Text("RiseVBT")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.black.opacity(0.8))
                    .padding(-1.0)
                Text("Train with Data\n Lift with Power")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.black.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    StartView()
}
