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
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DataModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .modelContainer(sharedModelContainer)
        }
    }
}
