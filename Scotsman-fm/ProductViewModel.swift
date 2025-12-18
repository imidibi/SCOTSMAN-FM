//
//  ProductViewModel.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//
import Foundation
import CoreData

enum ProductSortOption: String, CaseIterable {
    case name = "Name"
    case unitCost = "Unit Cost"
    case unitPrice = "Unit Price"
}

class ProductViewModel: ObservableObject {
    @Published var products: [ProductWrapper] = []
    @Published var searchText: String = ""  // ✅ Search text state
    @Published var sortOption: ProductSortOption = .name {
        didSet {
            fetchProducts()  // Re-fetch and sort products when sortOption changes
        }
    }

    private let context = CoreDataManager.shared.context

    init() {
        fetchProducts()
    }

    func fetchProducts() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ProductEntity")

        // Apply sorting based on the selected option
        switch sortOption {
        case .name:
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        case .unitCost:
            request.sortDescriptors = [NSSortDescriptor(key: "unitCost", ascending: true)]
        case .unitPrice:
            request.sortDescriptors = [NSSortDescriptor(key: "unitPrice", ascending: true)]
        }

        do {
            let fetchedProducts = try context.fetch(request)
            var wrappedProducts = fetchedProducts.map { ProductWrapper(managedObject: $0) }

            // Apply search filter
            if !searchText.isEmpty {
                wrappedProducts = wrappedProducts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }

            // Sort products manually if Core Data sorting is not working as expected
            switch sortOption {
            case .name:
                wrappedProducts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            case .unitCost:
                wrappedProducts.sort { $0.unitCost < $1.unitCost }
            case .unitPrice:
                wrappedProducts.sort { $0.unitPrice < $1.unitPrice }
            }

            self.products = wrappedProducts
        } catch {
            // print("Error fetching products: \(error)")
        }
    }

    func addProduct(name: String, unitCost: Double, unitPrice: Double, type: String, benefits: String, prodDescription: String, units: String) {
        let entity = NSEntityDescription.entity(forEntityName: "ProductEntity", in: context)!
        let newProduct = NSManagedObject(entity: entity, insertInto: context)

        newProduct.setValue(name, forKey: "name")
        newProduct.setValue(type, forKey: "type")
        newProduct.setValue(units, forKey: "units")
        newProduct.setValue(benefits, forKey: "benefits")
        newProduct.setValue(prodDescription, forKey: "prodDescription")
        newProduct.setValue(unitCost, forKey: "unitCost")
        newProduct.setValue(unitPrice, forKey: "unitPrice")

        saveData()
    }

    func updateProduct(product: ProductWrapper, name: String, unitCost: Double, unitPrice: Double, type: String, benefits: String, prodDescription: String, units: String) {
        product.managedObject.setValue(name, forKey: "name")
        product.managedObject.setValue(type, forKey: "type")
        product.managedObject.setValue(units, forKey: "units")
        product.managedObject.setValue(benefits, forKey: "benefits")
        product.managedObject.setValue(prodDescription, forKey: "prodDescription")
        product.managedObject.setValue(unitCost, forKey: "unitCost")
        product.managedObject.setValue(unitPrice, forKey: "unitPrice")

        saveData()
    }

    func deleteProduct(product: ProductWrapper) {
        context.delete(product.managedObject)
        saveData()
    }

    private func saveData() {
        do {
            try context.save()
            fetchProducts()
        } catch {
            // print("Error saving product data: \(error)")
        }
    }
}
// MARK: - Wrapper for Identifiable Compliance
struct ProductWrapper: Identifiable, Hashable {
    let managedObject: NSManagedObject

    var id: NSManagedObjectID { managedObject.objectID }

    var name: String {
        managedObject.value(forKey: "name") as? String ?? ""
    }

    var type: String {
        managedObject.value(forKey: "type") as? String ?? ""
    }

    var units: String {
        managedObject.value(forKey: "units") as? String ?? ""
    }

    var benefits: String {
        managedObject.value(forKey: "benefits") as? String ?? ""
    }

    var prodDescription: String {
        managedObject.value(forKey: "prodDescription") as? String ?? ""
    }

    var unitCost: Double {
        managedObject.value(forKey: "unitCost") as? Double ?? 0.0
    }

    var unitPrice: Double {
        managedObject.value(forKey: "unitPrice") as? Double ?? 0.0
    }

    // ✅ Conform to Hashable
    static func == (lhs: ProductWrapper, rhs: ProductWrapper) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

}
