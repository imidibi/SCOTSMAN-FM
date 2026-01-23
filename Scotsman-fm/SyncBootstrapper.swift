import Foundation
import CoreData
import Combine

final class SyncBootstrapper: ObservableObject {
    private var cancellable: AnyCancellable?

    init(context: NSManagedObjectContext, hubSpotAuth: HubSpotAuthManager) {
        cancellable = NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: context)
            .sink { notification in
                Task {
                    // Read isConnected on the main actor to satisfy @MainActor isolation
                    let connected = await MainActor.run { hubSpotAuth.isConnected }
                    guard connected else { return }

                    if let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> {
                        for obj in inserted {
                            await self.syncIfNeeded(obj, hubSpotAuth: hubSpotAuth)
                        }
                    }
                    if let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
                        for obj in updated {
                            await self.syncIfNeeded(obj, hubSpotAuth: hubSpotAuth)
                        }
                    }
                }
            }
    }

    private func syncIfNeeded(_ obj: NSManagedObject, hubSpotAuth: HubSpotAuthManager) async {
        if let opp = obj as? OpportunityEntity {
            await SyncManager.shared.syncOpportunity(opp, hubSpotAuth: hubSpotAuth)
        } else if let company = obj as? CompanyEntity {
            await SyncManager.shared.syncCompany(company, hubSpotAuth: hubSpotAuth)
        }
    }
}

