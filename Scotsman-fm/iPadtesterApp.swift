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
    @StateObject private var hubSpotAuth = HubSpotAuthManager.shared

    @StateObject private var syncBootstrapperHolder = Holder()

    class Holder: ObservableObject {
        var bootstrapper: SyncBootstrapper?
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.persistentContainer.viewContext)
                .environmentObject(coreDataManager)
                .environmentObject(hubSpotAuth)
                .onAppear {
                    // Initialize the save observer once
                    if syncBootstrapperHolder.bootstrapper == nil {
                        syncBootstrapperHolder.bootstrapper = SyncBootstrapper(
                            context: coreDataManager.persistentContainer.viewContext,
                            hubSpotAuth: hubSpotAuth
                        )
                    }

                    // Run a full sync at startup when connected
                    Task {
                        guard hubSpotAuth.isConnected else { return }
                        await SyncManager.shared.syncAllOnStartup(hubSpotAuth: hubSpotAuth)
                    }
                }
        }
    }

    init() {
        coreDataManager.fetchEntityDescriptions()
    }
}
