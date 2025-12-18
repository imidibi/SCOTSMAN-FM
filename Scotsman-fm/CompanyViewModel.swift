//
//  CompanyViewModel.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//
import Foundation
import CoreData
import SwiftUI

class CompanyViewModel: ObservableObject {
    @Published var companies: [CompanyWrapper] = [] // ✅ Uses a wrapper instead of NSManagedObject
    @Published var deletionErrorMessage: String? = nil // Add this line to hold error messages for the UI

    private let context = CoreDataManager.shared.context

    init() {
        fetchCompanies()
    }

    func fetchCompanies() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CompanyEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        do {
            let fetchedCompanies = try context.fetch(request)
            self.companies = fetchedCompanies.map { CompanyWrapper(managedObject: $0) }
        } catch {
            // print("Error fetching companies: \(error)")
        }
    }

    func addCompany(name: String, address: String, address2: String, city: String, state: String, zipCode: String, mainContact: String, webAddress: String, companyType: Int) {
        let entity = NSEntityDescription.entity(forEntityName: "CompanyEntity", in: context)!
        let newCompany = NSManagedObject(entity: entity, insertInto: context)

        newCompany.setValue(name, forKey: "name")
        newCompany.setValue(address, forKey: "address")
        newCompany.setValue(address2, forKey: "address2")
        newCompany.setValue(city, forKey: "city")
        newCompany.setValue(state, forKey: "state")
        newCompany.setValue(zipCode, forKey: "zipCode")
        newCompany.setValue(mainContact, forKey: "mainContact")
        newCompany.setValue(webAddress, forKey: "webAddress")
        newCompany.setValue(companyType, forKey: "companyType")

        saveData()
    }

    func updateCompany(company: CompanyWrapper, name: String, address: String, address2: String, city: String, state: String, zipCode: String, mainContact: String, webAddress: String, companyType: Int) {
        company.managedObject.setValue(name, forKey: "name")
        company.managedObject.setValue(address, forKey: "address")
        company.managedObject.setValue(address2, forKey: "address2")
        company.managedObject.setValue(city, forKey: "city")
        company.managedObject.setValue(state, forKey: "state")
        company.managedObject.setValue(zipCode, forKey: "zipCode")
        company.managedObject.setValue(mainContact, forKey: "mainContact")
        company.managedObject.setValue(webAddress, forKey: "webAddress")
        company.managedObject.setValue(companyType, forKey: "companyType")

        saveData()
    }

    func deleteCompany(company: CompanyWrapper) {
        // Check for linked data before deletion
        let opportunityRequest = NSFetchRequest<NSManagedObject>(entityName: "OpportunityEntity")
        opportunityRequest.predicate = NSPredicate(format: "company == %@", company.managedObject)
        
        let meetingRequest = NSFetchRequest<NSManagedObject>(entityName: "MeetingsEntity")
        meetingRequest.predicate = NSPredicate(format: "company == %@", company.managedObject)
        
        let contactRequest = NSFetchRequest<NSManagedObject>(entityName: "ContactsEntity")
        contactRequest.predicate = NSPredicate(format: "company == %@", company.managedObject)
        
        do {
            let linkedOpportunities = try context.fetch(opportunityRequest)
            let linkedMeetings = try context.fetch(meetingRequest)
            let linkedContacts = try context.fetch(contactRequest)
            
            if !linkedOpportunities.isEmpty || !linkedMeetings.isEmpty || !linkedContacts.isEmpty {
                // print("Linked data - cannot delete")
                deletionErrorMessage = "Linked data exists - Company cannot be deleted."
                return // Prevent deletion if linked data exists
            }
            
            context.delete(company.managedObject) // Proceed with deletion if no linked data found
            saveData()
        } catch {
            // print("Error checking for linked data: \(error)")
            deletionErrorMessage = "Error checking for linked data: \(error.localizedDescription)"
        }
    }

    private func saveData() {
        do {
            try context.save()
            fetchCompanies()
        } catch {
            // print("Error saving company data: \(error)")
        }
    }
}

// MARK: - Wrapper for Identifiable Compliance
struct CompanyWrapper: Identifiable, Hashable {
    let managedObject: NSManagedObject

    var id: NSManagedObjectID { managedObject.objectID }

    var name: String {
        managedObject.value(forKey: "name") as? String ?? ""
    }

    var address: String {
        managedObject.value(forKey: "address") as? String ?? ""
    }
    var address2: String {
        managedObject.value(forKey: "address2") as? String ?? ""
    }
    
    var city: String {
        managedObject.value(forKey: "city") as? String ?? ""
    }
    var state: String {
        managedObject.value(forKey: "state") as? String ?? ""
    }
    var zipCode: String {
        managedObject.value(forKey: "zipCode") as? String ?? ""
    }

    var mainContact: String {
        managedObject.value(forKey: "mainContact") as? String ?? ""
    }

    var webAddress: String {
        managedObject.value(forKey: "webAddress") as? String ?? ""
    }

    var companyType: Int {
        managedObject.value(forKey: "companyType") as? Int ?? 0
    }

    var companyTypeDescription: String {
        switch companyType {
        case 1:
            return "Customer"
        case 2:
            return "Lead"
        case 3:
            return "Prospect"
        default:
            return "Unknown"
        }
    }

    // ✅ Conform to Hashable
    static func == (lhs: CompanyWrapper, rhs: CompanyWrapper) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
