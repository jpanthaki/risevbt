//
//  HomeView.swift
//  DataView
//
//  Created by Jamshed Panthaki on 3/10/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Home Page View")
                    .font(.largeTitle)
                    .padding()
                NavigationLink(destination: ChartView(dataCollection: DataViewModel())) {
                    Text("Go to chart view")
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
