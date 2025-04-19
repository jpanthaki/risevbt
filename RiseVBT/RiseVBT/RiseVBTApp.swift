//
//  RiseVBTApp.swift
//  RiseVBT
//
//  Created by Jamshed Panthaki on 4/2/25.
//

import SwiftUI
import SwiftData

@main
struct RiseVBTApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(
                    for: [
                        DataModel.self
                    ]
                )
        }
    }
}
