import CoreData

class CoreDataManager: ObservableObject {
static let shared = CoreDataManager()

let persistentContainer: NSPersistentContainer

private init() {
    persistentContainer = NSPersistentContainer(name: "CompanyDataModel")
    persistentContainer.loadPersistentStores { (_, _) in
        // Persistent store loaded. Add error handling if needed.
    }
    fetchEntityDescriptions()
}

var context: NSManagedObjectContext {
    return persistentContainer.viewContext
}

func saveContext() {
    let context = persistentContainer.viewContext
    if context.hasChanges {
        do {
            try context.save()
        } catch {
            // print("Unresolved error \(error)")
        }
    }
}

    /// Fetches the AssessmentEntity for a company by name, or creates it if needed.
    func getOrCreateAssessment(for companyName: String) -> AssessmentEntity {
        let normalizedCompanyName = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let request: NSFetchRequest<AssessmentEntity> = AssessmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "company.name == %@", normalizedCompanyName)

        if let existing = try? self.context.fetch(request).first {
            return existing
        } else {
            let newAssessment = AssessmentEntity(context: self.context)
            newAssessment.id = UUID()
            newAssessment.date = Date()

            guard let company = self.fetchCompanyByName(name: normalizedCompanyName) else {
                fatalError("❌ Could not find or create CompanyEntity for: \(normalizedCompanyName)")
            }

            newAssessment.company = company
            return newAssessment
        }
    }

func syncCompaniesFromAutotask(companies: [(name: String, address1: String?, address2: String?, city: String?, state: String?, zipCode: String?, webAddress: String?, companyType: Int?)]) {
    let context = persistentContainer.viewContext

    for company in companies {
        let fetchRequest: NSFetchRequest<CompanyEntity> = CompanyEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", company.name)

        do {
            let results = try context.fetch(fetchRequest)
            let companyEntity = results.first ?? CompanyEntity(context: context)

            companyEntity.name = company.name
            companyEntity.address = company.address1
            companyEntity.address2 = company.address2
            companyEntity.city = company.city
            companyEntity.state = company.state
            companyEntity.zipCode = company.zipCode
            companyEntity.webAddress = company.webAddress
            companyEntity.companyType = Int16(company.companyType ?? 0)

        } catch {
            // print("Error fetching company: \(error)")
        }
    }

    saveContext()
}

func fetchCompanies() -> [CompanyEntity] {
    let request: NSFetchRequest<CompanyEntity> = CompanyEntity.fetchRequest()
    request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
    
    do {
        return try context.fetch(request)
    } catch {
        // print("Failed to fetch companies: \(error)")
        return []
    }
}

func fetchSecurityAssessments(for company: CompanyEntity) -> [SecAssessEntity] {
    let request: NSFetchRequest<SecAssessEntity> = SecAssessEntity.fetchRequest()

    guard let companyName = company.name, !companyName.isEmpty else {
        // print("❌ Error: Company Name is nil or invalid")
        return []
    }
    
    request.predicate = NSPredicate(format: "company.name == %@", companyName)
    request.sortDescriptors = [NSSortDescriptor(key: "assessDate", ascending: false)]

    do {
        let assessments = try context.fetch(request)
        return assessments
    } catch {
        // print("❌ Fetch Error: \(error.localizedDescription)")
        return []
    }
}

func saveSecurityAssessment(for company: CompanyEntity, assessmentData: [SecurityAssessmentView.Status]) {
    let newAssessment = SecAssessEntity(context: context)
    newAssessment.id = UUID()
    newAssessment.assessDate = Date()
    
    newAssessment.company = company
    
    newAssessment.secAssess = assessmentData[0].rawValue
    newAssessment.secAware = assessmentData[1].rawValue
    newAssessment.darkWeb = assessmentData[2].rawValue
    newAssessment.backup = assessmentData[3].rawValue
    newAssessment.emailProtect = assessmentData[4].rawValue
    newAssessment.advancedEDR = assessmentData[5].rawValue
    newAssessment.mobDevice = assessmentData[6].rawValue
    newAssessment.phySec = assessmentData[7].rawValue
    newAssessment.passwords = assessmentData[8].rawValue
    newAssessment.siemSoc = assessmentData[9].rawValue
    newAssessment.firewall = assessmentData[10].rawValue
    newAssessment.dnsProtect = assessmentData[11].rawValue
    newAssessment.mfa = assessmentData[12].rawValue
    newAssessment.compUpdates = assessmentData[13].rawValue
    newAssessment.encryption = assessmentData[14].rawValue
    newAssessment.cyberInsurance = assessmentData[15].rawValue
    
    do {
        try context.save()
    } catch {
        // print("❌ Failed to save security assessment: \(error.localizedDescription)")
    }
}

func deleteSecurityAssessment(_ assessment: SecAssessEntity) {
    context.delete(assessment)
    do {
        try context.save()
        // print("Security assessment deleted successfully.")
    } catch {
        // print("Failed to delete security assessment: \(error)")
    }
}

func fetchCompanyByName(name: String) -> CompanyEntity? {
    let request: NSFetchRequest<CompanyEntity> = CompanyEntity.fetchRequest()
    request.predicate = NSPredicate(format: "name ==[c] %@", name.trimmingCharacters(in: .whitespacesAndNewlines))
    
    do {
        return try context.fetch(request).first
    } catch {
        // print("Failed to fetch company: \(error)")
        return nil
    }
}

func debugFetchAllAssessments() {
    let request: NSFetchRequest<SecAssessEntity> = SecAssessEntity.fetchRequest()
    
    do {
        _ = try context.fetch(request)
    } catch {
        // print("❌ Fetch All Assessments Error: \(error.localizedDescription)")
    }
}

func importContacts(contacts: [String], company: CompanyEntity) {
    let context = persistentContainer.viewContext
    for contactName in contacts {
        let nameComponents = contactName.split(separator: " ", maxSplits: 1).map { String($0) }
        let firstName = nameComponents.first ?? ""
        let lastName = nameComponents.count > 1 ? nameComponents[1] : ""
        
        let fetchRequest: NSFetchRequest<ContactsEntity> = ContactsEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "firstName ==[c] %@ AND lastName ==[c] %@", firstName.trimmingCharacters(in: .whitespacesAndNewlines), lastName.trimmingCharacters(in: .whitespacesAndNewlines))
        
        do {
            let results = try context.fetch(fetchRequest)
            if results.isEmpty {
                let newContact = ContactsEntity(context: context)
                newContact.id = UUID()
                newContact.firstName = firstName
                newContact.lastName = lastName
                newContact.company = company  // Link the contact to the existing company
            }
        } catch {
            // print("Error fetching contact: \(error)")
        }
    }
    saveContext()
}

    func fetchOrCreateCompany(companyID: Int, companyName: String, completion: @escaping (CompanyEntity) -> Void) {
        let context = persistentContainer.viewContext
        let normalizedName = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let nameRequest: NSFetchRequest<CompanyEntity> = CompanyEntity.fetchRequest()
        nameRequest.predicate = NSPredicate(format: "name ==[c] %@", normalizedName)
        if let byName = try? context.fetch(nameRequest).first {
            if byName.autotaskID == 0 {
                byName.autotaskID = Int64(companyID)
            }
            self.saveContext()
            completion(byName)
            return
        }
        
        let idRequest: NSFetchRequest<CompanyEntity> = CompanyEntity.fetchRequest()
        idRequest.predicate = NSPredicate(format: "autotaskID == %d", companyID)
        if let byID = try? context.fetch(idRequest).first {
            if (byID.name ?? "").isEmpty {
                byID.name = normalizedName
                self.saveContext()
            }
            completion(byID)
            return
        }
        
        // Not found by name or ID, fetch from Autotask
        AutotaskAPIManager.shared.fetchFullCompanyDetails(companyID: companyID) { results in
            DispatchQueue.main.async {
                // Recheck by name to avoid duplication in race condition
                let recheckRequest: NSFetchRequest<CompanyEntity> = CompanyEntity.fetchRequest()
                recheckRequest.predicate = NSPredicate(format: "name ==[c] %@", normalizedName)
                if let existing = try? context.fetch(recheckRequest).first {
                    if existing.autotaskID == 0 {
                        existing.autotaskID = Int64(companyID)
                        self.saveContext()
                    }
                    completion(existing)
                    return
                }
                
                let newCompany = CompanyEntity(context: context)
                newCompany.autotaskID = Int64(companyID)
                newCompany.name = normalizedName

                if let fullCompany = results.first {
                    // fullCompany = (id, address1, address2, city, state, zip, web, companyType)
                    newCompany.address = fullCompany.1
                    newCompany.address2 = fullCompany.2
                    newCompany.city = fullCompany.3
                    newCompany.state = fullCompany.4
                    newCompany.zipCode = fullCompany.5
                    newCompany.webAddress = fullCompany.6
                    newCompany.companyType = Int16(fullCompany.7 ?? 0)
                }

                self.saveContext()
                completion(newCompany)
            }
        }
    }

func fetchEntityDescriptions() {
    let context = persistentContainer.viewContext
    let model = context.persistentStoreCoordinator?.managedObjectModel

    if let entities = model?.entities {
        for _ in entities {
            // print("✅ Loaded entity.")
        }
    } else {
        // print("❌ No entities found in the Core Data model.")
    }
}

func fetchOpportunities(for company: CompanyEntity) -> [OpportunityEntity] {
    let request: NSFetchRequest<OpportunityEntity> = OpportunityEntity.fetchRequest()
    request.predicate = NSPredicate(format: "company == %@", company)
    
    do {
        return try context.fetch(request)
    } catch {
        // print("❌ Error fetching opportunities: \(error)")
        return []
    }
}

func fetchContacts(for company: CompanyEntity) -> [ContactsEntity] {
    let request: NSFetchRequest<ContactsEntity> = ContactsEntity.fetchRequest()
    request.predicate = NSPredicate(format: "company == %@", company)
    
    do {
        return try context.fetch(request)
    } catch {
        // print("❌ Error fetching contacts: \(error)")
        return []
    }
}

func fetchMeetings(for company: CompanyEntity) -> [MeetingsEntity] {
    let request: NSFetchRequest<MeetingsEntity> = MeetingsEntity.fetchRequest()
    request.predicate = NSPredicate(format: "company == %@", company)
    
    do {
        return try context.fetch(request)
    } catch {
        // print("❌ Error fetching meetings: \(error)")
        return []
    }
}

func deleteCompany(company: CompanyEntity) {
    let opportunities = fetchOpportunities(for: company)
    let meetings = fetchMeetings(for: company)
    let contacts = fetchContacts(for: company)

    if !opportunities.isEmpty || !meetings.isEmpty || !contacts.isEmpty {
        // print("❌ Linked data - cannot delete company")
        return
    }
    
    context.delete(company)
    saveContext()
    // print("✅ Company deleted successfully.")
}

func saveMeeting(meeting: MeetingsEntity) {
    do {
        try context.save()
        // print("✅ Meeting successfully saved!")
    } catch {
        // print("❌ Failed to save meeting: \(error)")
    }
}

func saveAssessmentFields(for company: String, category: String, fields: [(String, String?, Bool?)]) {
    let normalizedCompanyName = company.trimmingCharacters(in: .whitespacesAndNewlines)
    let assessmentRequest: NSFetchRequest<AssessmentEntity> = AssessmentEntity.fetchRequest()
    assessmentRequest.predicate = NSPredicate(format: "company.name == %@", normalizedCompanyName)

    let assessment: AssessmentEntity
    if let existing = try? context.fetch(assessmentRequest).first {
        assessment = existing
    } else {
        assessment = AssessmentEntity(context: context)
        assessment.id = UUID()
        assessment.date = Date()
        guard let companyEntity = fetchCompanyByName(name: normalizedCompanyName) else {
            // print("❌ Could not find company entity for: \(normalizedCompanyName)")
            return
        }
        assessment.company = companyEntity
    }

    for fieldData in fields {
        let fieldName = fieldData.0
        let fieldRequest: NSFetchRequest<AssessmentFieldEntity> = AssessmentFieldEntity.fetchRequest()
        fieldRequest.predicate = NSPredicate(format: "assessment == %@ AND category == %@ AND fieldName == %@", assessment, category, fieldName)

        let fieldEntity: AssessmentFieldEntity
        if let existingField = try? context.fetch(fieldRequest).first {
            fieldEntity = existingField
        } else {
            fieldEntity = AssessmentFieldEntity(context: context)
            fieldEntity.id = UUID()
            fieldEntity.assessment = assessment
            fieldEntity.category = category
            fieldEntity.fieldName = fieldName
        }

        if let boolValue = fieldData.2 {
            fieldEntity.valueNumber = boolValue ? 1.0 : 0.0
            fieldEntity.valueString = boolValue ? "true" : "false"
        } else if let stringValue = fieldData.1, !stringValue.isEmpty {
            fieldEntity.valueString = stringValue
            fieldEntity.valueNumber = Double(stringValue) ?? 0.0
        }

        // print("✅ Saved field '\(fieldEntity.fieldName ?? "unnamed")' with valueNumber: \(fieldEntity.valueNumber), valueString: \(fieldEntity.valueString ?? "nil")")
    }

    saveContext()
    context.refresh(assessment, mergeChanges: true)
    // print("✅ Assessment fields saved successfully for company: \(company)")
}

func loadAssessmentFields(for company: String, category: String) -> [AssessmentFieldEntity] {
    let request: NSFetchRequest<AssessmentEntity> = AssessmentEntity.fetchRequest()
    let normalizedCompanyName = company.trimmingCharacters(in: .whitespacesAndNewlines)
    // Updated predicate to use company.name
    request.predicate = NSPredicate(format: "company.name == %@", normalizedCompanyName)

    guard let assessment = try? context.fetch(request).first,
          let fieldSet = assessment.fields as? Set<AssessmentFieldEntity> else {
        return []
    }

    // print("📥 Loading saved \(category) assessment for: \(company)")
    // print("✅ Loaded assessment for company: \(company)")
    // print("🧠 Loaded assessment: \(company) with \(fieldSet.count) total fields")

    // for field in fieldSet {
    //     print("🔍 Inspecting field: \(field.fieldName ?? "(unknown)"), valueNumber: \(field.valueNumber), valueString: \(field.valueString ?? "nil")")
    // }

    let filteredFields = fieldSet.filter { $0.category == category }
    return Array(filteredFields)
}

func loadAllAssessmentFields(for company: String, category: String? = nil) -> [AssessmentFieldEntity] {
    let request: NSFetchRequest<AssessmentEntity> = AssessmentEntity.fetchRequest()
    let normalizedCompanyName = company.trimmingCharacters(in: .whitespacesAndNewlines)
    // Updated predicate to use company.name
    request.predicate = NSPredicate(format: "company.name == %@", normalizedCompanyName)

    guard let assessment = try? context.fetch(request).first,
          let fieldSet = assessment.fields as? Set<AssessmentFieldEntity> else {
        return []
    }

    if let category = category {
        return Array(fieldSet.filter { $0.category == category })
    } else {
        return Array(fieldSet)
    }
}
}
