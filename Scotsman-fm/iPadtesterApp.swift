//
//  iPadtesterApp.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//

import SwiftUI

@main
struct iPadtesterApp: App {
    let coreDataManager = CoreDataManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.persistentContainer.viewContext)
                .environmentObject(coreDataManager)
        }
    }
    
    init() {
        coreDataManager.fetchEntityDescriptions()
    }
}
