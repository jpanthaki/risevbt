//
//  HomeView.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/4/25.
//

import SwiftUI

struct HomeView: View {
    
    var body: some View {
        NavigationStack {
            ZStack{
                Color.blue.opacity(0.5)
                    .ignoresSafeArea()
                
                VStack {
                    Text("RiseVBT")
                        .font(.title)
                        .foregroundColor(.black.opacity(0.7))
                        .fontWeight(.heavy)
                        .padding(.bottom, -2.0)
                        .padding(.top, 2.0)
                    ZStack {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.blue.opacity(0.4))
                        VStack {
                            NavigationLink(destination: Page1View()) {
                                RoundedRectangle(cornerRadius:20)
                                    .fill(Color.gray.opacity(0.4))
                                    .padding()
                                    .overlay(
                                        Text("Connect RiseVBT\nDevice")
                                            .fontWeight(.heavy)
                                            .foregroundColor(.black.opacity(0.7))
                                            .font(.title)
                                    )
                            }
                            NavigationLink(destination: RecordViewThatWorks()) {
                                RoundedRectangle(cornerRadius:20)
                                    .fill(Color.gray.opacity(0.4))
                                    .padding()
                                    .overlay(
                                        Text("Record Lift")
                                            .fontWeight(.heavy)
                                            .foregroundColor(.black.opacity(0.7))
                                            .font(.title)
                                    )
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

//sample views for testing
struct Page1View: View {
    var body: some View {
        Text("Welcome to Page 1")
            .font(.largeTitle)
    }
}

struct Page2View: View {
    var body: some View {
        Text("Welcome to Page 2")
            .font(.largeTitle)
    }
}

#Preview {
    HomeView()
}
