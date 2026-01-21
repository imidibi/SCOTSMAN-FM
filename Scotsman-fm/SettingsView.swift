import CoreData
import SwiftUI
import UIKit
import AuthenticationServices
import CryptoKit
import OSLog

struct Contact: Hashable {
    let firstName: String
    let lastName: String
}

struct SettingsView: View {
    @ObservedObject var companyViewModel: CompanyViewModel
    @EnvironmentObject private var hubSpotAuth: HubSpotAuthManager
    @AppStorage("autotaskEnabled") private var autotaskEnabled = false
    @AppStorage("autotaskAPIUsername") private var apiUsername = ""
    @AppStorage("autotaskAPISecret") private var apiSecret = ""
    @AppStorage("autotaskAPITrackingID") private var apiTrackingID = ""
    @AppStorage("myName") private var myName = ""
    @AppStorage("myEmail") private var myEmail = ""
    @AppStorage("myCompanyName") private var myCompanyName = ""
    @AppStorage("myCompanyURL") private var myCompanyURL = ""
    @AppStorage("selectedMethodology") private var selectedMethodology = "BANT"
    @AppStorage("openAIKey") private var openAIKey = ""
    @AppStorage("openAISelectedModel") private var openAISelectedModel: String = ""

    // Store available OpenAI chat models for dynamic Picker
    @State private var availableModels: [String] = []
    
    @State private var testResult: String = ""
    @State private var autotaskResult: String = ""
    @State private var openAIModel: String = "Not yet retrieved"
    @State private var isTesting = false
    @State private var companyName: String = ""
    @State private var searchResults: [(Int, String, String)] = []
    @State private var productSearchResults: [(Int, String, String)] = []
    @State private var selectedCompanies: Set<String> = []
    @State private var selectedContacts: [Contact] = []
    @State private var showAutotaskSettings = false
    @State private var selectedCategory: String = "Company"
    @State private var showContactSearch = false
    @State private var contactName: String = ""
    @State private var selectedCompanyID: Int? = nil
    @State private var selectedOpportunities: [OpportunityEntity] = []
    @State private var showOpportunitySearch = false
    @State private var showSyncButton = false
    @State private var opportunityImportCache: [(Int, String, Int?, Double?, Double?, Int?, Date?)] = []
// Product selection state
struct ProductSelection: Hashable {
    let name: String
}
@State private var selectedProductNames: Set<String> = []
    @State private var showProductSearch = false
    @State private var productImportCache: [(Int, String, String, String, Double?, Double?, Date?)] = []
    @State private var hasValidatedOpenAIKey = false
    
    // HubSpot selective import (search + pick)
    @State private var hubspotDealSearchText: String = ""
    @State private var hubspotDealSearchResults: [HubSpotDealSummary] = []
    @State private var selectedHubSpotDealIDs: Set<String> = []
    @State private var hubspotStatusMessage: String = ""
    @State private var isHubspotSearching: Bool = false
    @State private var isHubspotImporting: Bool = false
    @State private var showHubspotDealPicker: Bool = false
    @State private var hubspotImportTapCount: Int = 0

    private var searchHeaderText: String {
        switch selectedCategory {
        case "Contact":
            return "Search Contacts in Autotask"
        case "Opportunity":
            return "Search Opportunities in Autotask"
        case "Service":
            return "Search Services in Autotask"
        default:
            return "Search Companies in Autotask"
        }
    }
    
    private func resetImportState() {
        companyName = ""
        selectedCompanyID = nil
        selectedCompanies.removeAll()
        selectedContacts.removeAll()
        selectedOpportunities.removeAll()
        selectedProductNames.removeAll()
        searchResults.removeAll()
        contactName = ""
        productSearchResults.removeAll()
        opportunityImportCache.removeAll()
        productImportCache.removeAll()
        showContactSearch = false
        showOpportunitySearch = false
        showProductSearch = false
        showSyncButton = false
    }

    private func fetchAllOpportunitiesForSelectedCompany() {

        guard let companyID = selectedCompanyID else {
            // No company selected.
            return
        }

        let requestBody: [String: Any] = [
            "MaxRecords": 100,
            "IncludeFields": ["id", "title", "amount", "probability", "monthlyRevenue", "onetimeRevenue", "status", "projectedCloseDate"],
            "Filter": [
                [
                    "op": "and",
                    "items": [
                        ["op": "eq", "field": "CompanyID", "value": companyID],
                        ["op": "eq", "field": "status", "value": 1]
                    ]
                ]
            ]
        ]

        AutotaskAPIManager.shared.searchOpportunitiesFromBody(requestBody) { results in
            // results: [(Int, String, Int?, Double?, Double?, Int?, Date?)]
            DispatchQueue.main.async {
                searchResults = results.map { ($0.0, $0.1, "") }
                opportunityImportCache = results.map { ($0.0, $0.1, $0.2, $0.3, $0.4, $0.5, $0.6) }
                // Opportunities fetched.
            }
        }
    }

    private var opportunitySearchField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Opportunities")
                .font(.headline)
            
            Button(action: {
                showOpportunitySearch = true
                fetchAllOpportunitiesForSelectedCompany()  // Trigger the API call when opening the overlay
            }) {
                HStack {
                    Text(selectedOpportunities.isEmpty ? "Select Opportunities" : selectedOpportunities.map { "\($0.name ?? "Unnamed Opportunity")" }.joined(separator: ", "))
                        .foregroundColor(selectedOpportunities.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
        }
    }

    private func importSelectedOpportunities() {
        guard let companyID = selectedCompanyID else {
            // No company selected.
            return
        }

        let companyCopy = companyName
        autotaskResult = "✅ Imported \(selectedOpportunities.count) opportunities successfully for company \(companyCopy)."

        CoreDataManager.shared.fetchOrCreateCompany(companyID: companyID, companyName: companyName) { companyEntity in
            let context = CoreDataManager.shared.persistentContainer.viewContext

            for opportunity in selectedOpportunities where opportunity.name != nil {
                if let cached = opportunityImportCache.first(where: { $0.1 == opportunity.name }) {
                    opportunity.autotaskID = Int64(cached.0)
                    opportunity.probability = Int16(cached.2 ?? 0)
                    opportunity.monthlyRevenue = cached.3 ?? 0
                    opportunity.onetimeRevenue = cached.4 ?? 0
                    opportunity.estimatedValue = (cached.3 ?? 0) * 12 + (cached.4 ?? 0)
                    opportunity.status = (1...3).contains(cached.5 ?? 0) ? Int16(cached.5!) : 1
                    opportunity.closeDate = cached.6
                }

                opportunity.company = companyEntity
                context.insert(opportunity)
            }

            CoreDataManager.shared.saveContext()

            DispatchQueue.main.async {
                // Imported opportunities for company.
                autotaskResult = "✅ Imported \(selectedOpportunities.count) opportunities successfully for company \(companyName)."
                resetImportState()
            }
        }
    }

    private var opportunitySelectionOverlay: some View {
        VStack {
            Text("Select Opportunities")
                .font(.headline)
                .padding()
            
            // Search field for opportunities (locked TextField)
            TextField("Search opportunities", text: $companyName)
                .disabled(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding([.leading, .trailing])

            ScrollView {
                LazyVStack {
                    ForEach(searchResults, id: \.0) { result in
                        let opportunityName = result.1
                        HStack {
                            Text(opportunityName)
                            Spacer()
                            if selectedOpportunities.contains(where: { $0.name == opportunityName }) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .onTapGesture {
                            if let index = selectedOpportunities.firstIndex(where: { $0.name == opportunityName }) {
                                selectedOpportunities.remove(at: index)
                            } else {
                                let tempOpportunity = OpportunityEntity(context: CoreDataManager.shared.persistentContainer.viewContext)
                                tempOpportunity.name = opportunityName
                                selectedOpportunities.append(tempOpportunity)
                            }
                        }
                    }
                }
            }
            
            Button("Done") {
                showOpportunitySearch = false
                if !selectedOpportunities.isEmpty {
                    // Trigger the display of the sync button
                    showSyncButton = true
                }
                // Only clear companyName and selectedCompanyID if no opportunities are selected
                if selectedOpportunities.isEmpty {
                    companyName = ""
                    selectedCompanyID = nil
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .frame(width: 600, height: 500)
        .shadow(radius: 20)
        .padding()
        .overlay(
            Group {
                if isHubspotImporting {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView("Importing…")
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(12)
                    }
                }
            }
        )
        .onAppear {
            fetchAllOpportunitiesForSelectedCompany()
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    }
    
    private var autotaskIntegrationSection: some View {
        Section(header:
            HStack {
                Text("Autotask Integration")
                Spacer()
                NavigationLink(destination: AutotaskHelpView()) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.blue)
                }
            }
        ) {
            Toggle("Enable Autotask API", isOn: $autotaskEnabled)
                .onChange(of: autotaskEnabled) { oldValue, newValue in
                    if newValue {
                        showAutotaskSettings = true  // Show settings when enabling API
                    }
                }

            if autotaskEnabled {
                Toggle("Show Settings", isOn: $showAutotaskSettings)

                if showAutotaskSettings {
                    HStack {
                        Text("API Username:")
                        TextField("", text: $apiUsername)
                            .textContentType(.username)
                            .autocapitalization(.none)
                    }
                    HStack {
                        Text("API Secret:")
                        SecureField("", text: $apiSecret)
                            .textContentType(.password)
                    }
                    HStack {
                        Text("Tracking Identifier:")
                        TextField("", text: $apiTrackingID)
                            .autocapitalization(.none)
                    }
                }
            }
        }
    }
    
    // MARK: - HubSpot Integration Section (extracted to help the compiler)
    private var hubSpotIntegrationSection: some View {
        Section(header: Text("HubSpot Integration")) {
            HStack {
                Text("Status")
                Spacer()
                Text(hubSpotAuth.isConnected ? "Connected" : "Not connected")
                    .foregroundColor(hubSpotAuth.isConnected ? .green : .red)
            }

            Button("Connect HubSpot") {
                hubSpotAuth.startOAuth()
            }
            .disabled(hubSpotAuth.isConnected)

            if !hubSpotAuth.lastAuthorizeURL.isEmpty {
                Text(hubSpotAuth.lastAuthorizeURL)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            if hubSpotAuth.isConnected {
                Button(isHubspotSearching ? "Loading deals…" : "Sync Deals Now") {
                    hubSpotSyncDealsNowTapped()
                }
                .disabled(isHubspotSearching)

                if !hubspotStatusMessage.isEmpty {
                    Text(hubspotStatusMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Button("Disconnect") {
                    hubSpotDisconnectTapped()
                }
                .foregroundColor(.red)
            }

            Text(hubSpotAuth.lastSyncDescription)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - HubSpot actions (helpers to avoid EnvironmentObject wrapper inference issues)
    private func hubSpotSyncDealsNowTapped() {
        guard hubSpotAuth.isConnected else { return }
        isHubspotSearching = true
        hubspotStatusMessage = ""
        selectedHubSpotDealIDs.removeAll()

        Task {
            do {
                let deals = try await hubSpotAuth.fetchDealSummaries(limit: 50)
                await MainActor.run {
                    hubspotDealSearchResults = deals
                    hubspotStatusMessage = deals.isEmpty ? "No deals returned." : "Fetched \(deals.count) deals. Select which to import."
                    isHubspotSearching = false
                    showHubspotDealPicker = true
                }
            } catch {
                await MainActor.run {
                    hubspotStatusMessage = "HubSpot fetch failed: \(error)"
                    isHubspotSearching = false
                }
            }
        }
    }

    private func hubSpotDisconnectTapped() {
        hubSpotAuth.disconnect()
    }

    // MARK: - HubSpot Deal Picker (POC)
    private var hubspotDealPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Select deals to import")
                    .font(.headline)
                Text("Selected: \(selectedHubSpotDealIDs.count)  Importing: \(isHubspotImporting ? "Yes" : "No")  Sheet: \(showHubspotDealPicker ? "Shown" : "Hidden")  Taps: \(hubspotImportTapCount)")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if hubspotDealSearchResults.isEmpty {
                    Text("No deals to show.")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(hubspotDealSearchResults) { deal in
                            HStack {
                                Text(deal.name)
                                Spacer()
                                if selectedHubSpotDealIDs.contains(deal.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedHubSpotDealIDs.contains(deal.id) {
                                    selectedHubSpotDealIDs.remove(deal.id)
                                } else {
                                    selectedHubSpotDealIDs.insert(deal.id)
                                }
                            }
                        }
                    }
                }

                HStack {
                    Button("Close") {
                        showHubspotDealPicker = false
                    }

                    Spacer()

                    Button(isHubspotImporting ? "Importing…" : "Import Selected") {
                        hubspotImportTapCount += 1
                        hubspotImportSelectedDealsTapped()
                    }
                    .disabled(selectedHubSpotDealIDs.isEmpty || isHubspotImporting)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("HubSpot Deals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showHubspotDealPicker = false }
                }
            }
            .overlay(
                Group {
                    if isHubspotImporting {
                        ZStack {
                            Color.black.opacity(0.2).ignoresSafeArea()
                            ProgressView("Importing…")
                                .padding()
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(12)
                        }
                    }
                }
            )
        }
    }

    private func hubspotImportSelectedDealsTapped() {
        isHubspotImporting = true
        // print("[HubSpot Import] Import started; selected deal IDs: \(selectedHubSpotDealIDs)")
        // print("[HubSpot Import] Current search results IDs: \(hubspotDealSearchResults.map{ $0.id })")
        let selectedIDs = selectedHubSpotDealIDs
        var failureCount = 0

        Task {
            let selectedIDsCopy = selectedIDs

            // Safety reset in case of early returns/errors
            defer {
                Task { @MainActor in
                    isHubspotImporting = false
                    showHubspotDealPicker = false
                    let successCount = max(0, selectedIDsCopy.count - failureCount)
                    if hubspotStatusMessage.isEmpty {
                        hubspotStatusMessage = failureCount > 0 ? "Imported \(successCount) deals with \(failureCount) errors." : "Successfully imported \(successCount) deals."
                    }
                    companyViewModel.fetchCompanies()
                }
            }

            let context = CoreDataManager.shared.persistentContainer.viewContext

            for dealID in selectedIDs {
                // print("[HubSpot Import] Iterating dealID=\(dealID)")
                guard let dealSummary = hubspotDealSearchResults.first(where: { $0.id == dealID }) else {
                    // print("[HubSpot Import] No dealSummary found for dealID=\(dealID). Skipping.")
                    failureCount += 1
                    continue
                }
                // print("[HubSpot Import] Found dealSummary for dealID=\(dealID): name=\(dealSummary.name)")

                // 1) Try to fetch full company details associated with the deal from HubSpot
                var resolvedCompany: CompanyEntity?
                var resolvedContact: (firstName: String, lastName: String, email: String?)?

                do {
                    // Prefer a direct association fetch
                    if let details = try await hubSpotAuth.fetchCompanyDetailsForDeal(dealID: dealID) {
                        let name = details.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let resolvedName = name.isEmpty ? deriveCompanyName(fromDealName: dealSummary.name) : name
                        // print("[HubSpot Import] DealID=\(dealID) resolved company via API: name=\(resolvedName), address1=\(details.address1 ?? "nil"), city=\(details.city ?? "nil"), state=\(details.state ?? "nil"), postal=\(details.postalCode ?? "nil")")
                        let company = fetchOrCreateCompanyByName(name: resolvedName, in: context)
                        if let v = details.address1 { company.address = v }
                        if let v = details.address2 { company.address2 = v }
                        if let v = details.city { company.city = v }
                        if let v = details.state { company.state = v }
                        if let v = details.postalCode { company.zipCode = v }
                        // Map HubSpot lifecycle stage to Core Data companyType (Int16)
                        if let stage = details.lifecycleStage?.lowercased() {
                            switch stage {
                            case "opportunity":
                                company.companyType = 3 // Prospect
                            case "customer":
                                company.companyType = 1 // Customer
                            default:
                                break // leave unchanged for other stages
                            }
                        }
                        resolvedCompany = company
                    } else {
                        let derivedCompanyName = deriveCompanyName(fromDealName: dealSummary.name)
                        // print("[HubSpot Import] DealID=\(dealID) no associated company returned; falling back to derived name: \(derivedCompanyName)")
                        resolvedCompany = bestMatchingOrCreateCompany(forDealName: dealSummary.name, derivedCompanyName: derivedCompanyName, in: context)
                    }
                } catch {
                    let derivedCompanyName = deriveCompanyName(fromDealName: dealSummary.name)
                    // print("[HubSpot Import] DealID=\(dealID) company details fetch failed; error=\(error). Falling back to derived name: \(derivedCompanyName)")
                    resolvedCompany = bestMatchingOrCreateCompany(forDealName: dealSummary.name, derivedCompanyName: derivedCompanyName, in: context)
                }

                // 2) Contact association (optional): Not implemented in HubSpotAuthManager; skipping for now.

                guard let companyEntity = resolvedCompany else {
                    failureCount += 1
                    continue
                }

                // 3) Upsert the opportunity under the resolved company
                let opportunityEntity = fetchOrCreateOpportunityByName(name: dealSummary.name, company: companyEntity, in: context)
                opportunityEntity.estimatedValue = 0
                opportunityEntity.status = 1
                // print("[HubSpot Import] Linked opportunity \(dealSummary.name) to company \(companyEntity.name ?? "(nil)")")

                // 4) Optionally upsert a contact and attach to company
                if let contact = resolvedContact {
                    upsertContact(firstName: contact.firstName, lastName: contact.lastName, email: contact.email, for: companyEntity, in: context)
                }

                CoreDataManager.shared.saveContext()
            }

            /*
            await MainActor.run {
                let successCount = selectedIDs.count - failureCount
                if failureCount > 0 {
                    hubspotStatusMessage = "Imported \(successCount) deals with \(failureCount) errors."
                } else {
                    hubspotStatusMessage = "Successfully imported \(successCount) deals."
                }
                selectedHubSpotDealIDs.removeAll()
                isHubspotImporting = false
                showHubspotDealPicker = false
                companyViewModel.fetchCompanies()
            }
            */
        }
    }
    
    // Helpers for Core Data persistence of HubSpot data
    
    private func fetchOrCreateCompanyByName(name: String, in context: NSManagedObjectContext) -> CompanyEntity {
        let fetchRequest: NSFetchRequest<CompanyEntity> = CompanyEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", name)
        fetchRequest.fetchLimit = 1
        
        if let existing = try? context.fetch(fetchRequest).first {
            if existing.name != name {
                existing.name = name
            }
            return existing
        } else {
            let newCompany = CompanyEntity(context: context)
            newCompany.name = name
            return newCompany
        }
    }
    
    private func fetchOrCreateOpportunityByName(name: String, company: CompanyEntity, in context: NSManagedObjectContext) -> OpportunityEntity {
        let fetchRequest: NSFetchRequest<OpportunityEntity> = OpportunityEntity.fetchRequest()
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "name ==[c] %@", name),
            NSPredicate(format: "company == %@", company)
        ])
        fetchRequest.fetchLimit = 1
        
        if let existing = try? context.fetch(fetchRequest).first {
            if existing.name != name {
                existing.name = name
            }
            existing.company = company
            return existing
        } else {
            let newOpportunity = OpportunityEntity(context: context)
            newOpportunity.name = name
            newOpportunity.company = company
            return newOpportunity
        }
    }
    
    private func upsertContact(firstName: String, lastName: String, email: String?, for company: CompanyEntity, in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<ContactsEntity> = ContactsEntity.fetchRequest()
        if let email = email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fetchRequest.predicate = NSPredicate(format: "company == %@ AND emailAddress ==[c] %@", company, email)
        } else {
            fetchRequest.predicate = NSPredicate(format: "company == %@ AND firstName ==[c] %@ AND lastName ==[c] %@", company, firstName, lastName)
        }
        fetchRequest.fetchLimit = 1
        
        if let existing = try? context.fetch(fetchRequest).first {
            var changed = false
            if existing.firstName != firstName {
                existing.firstName = firstName
                changed = true
            }
            if existing.lastName != lastName {
                existing.lastName = lastName
                changed = true
            }
            if let email = email, existing.emailAddress != email {
                existing.emailAddress = email
                changed = true
            }
            if changed {
                // No explicit save here; save after batch
            }
        } else {
            let newContact = ContactsEntity(context: context)
            newContact.id = UUID()
            newContact.firstName = firstName
            newContact.lastName = lastName
            newContact.emailAddress = email
            newContact.company = company
        }
    }
    
    // Helper to derive company name from a HubSpot deal name using common separators
    // Note: Used only as a fallback when HubSpot company details can't be fetched.
    private func deriveCompanyName(fromDealName dealName: String) -> String {
        let separators = [" - ", " – ", " — ", ":", "|"]
        for sep in separators {
            let components = dealName.components(separatedBy: sep)
            for component in components {
                let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return dealName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // New helper: bestMatchingOrCreateCompany
    private func bestMatchingOrCreateCompany(forDealName dealName: String, derivedCompanyName: String, in context: NSManagedObjectContext) -> CompanyEntity {
        // Fetch all companies
        let fetchRequest: NSFetchRequest<CompanyEntity> = CompanyEntity.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        
        guard let existingCompanies = try? context.fetch(fetchRequest) else {
            // If fetch fails, fallback to create by derivedCompanyName
            return fetchOrCreateCompanyByName(name: derivedCompanyName, in: context)
        }
        
        // Lowercased for comparisons
        let derivedLower = derivedCompanyName.lowercased()
        let dealNameLower = dealName.lowercased()
        
        // 1) Exact case-insensitive match on derivedCompanyName
        if let exactMatch = existingCompanies.first(where: { $0.name?.lowercased() == derivedLower }) {
            return exactMatch
        }
        
        // 2) Substring containment on dealName - find companies whose names appear in dealName
        let matchedCompanies = existingCompanies.filter {
            if let existingName = $0.name?.lowercased() {
                return dealNameLower.contains(existingName)
            }
            return false
        }
        
        if !matchedCompanies.isEmpty {
            // Choose longest matching name to avoid short false positives
            let longestMatch = matchedCompanies.max(by: {
                ($0.name?.count ?? 0) < ($1.name?.count ?? 0)
            })
            if let longestMatch = longestMatch {
                return longestMatch
            }
        }
        
        // 3) Fallback: create or fetch by derivedCompanyName
        return fetchOrCreateCompanyByName(name: derivedCompanyName, in: context)
    }
    
   var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("My Settings")) {
                    HStack {
                        Text("My Name:")
                        TextField("", text: $myName)
                            .textContentType(.name)
                    }
                    HStack {
                        Text("My Email Address:")
                        TextField("", text: $myEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                    }
                    HStack {
                        Text("My Company Name:")
                        TextField("", text: $myCompanyName)
                    }
                    HStack {
                        Text("My Company URL:")
                        TextField("", text: $myCompanyURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                }

                Section(header: Text("Qualification Methodology")) {
                    Picker("Methodology", selection: $selectedMethodology) {
                        Text("BANT").tag("BANT")
                        Text("MEDDIC").tag("MEDDIC")
                        Text("SCOTSMAN").tag("SCOTSMAN")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // --- OpenAI Integration Section ---
                Section(header:
                    HStack {
                        Text("OpenAI Integration")
                        Spacer()
                        NavigationLink(destination: OpenAIHelpView()) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                        }
                    }
                ) {
                    HStack {
                        Text("OpenAI API Key:")
                        SecureField("sk-...", text: $openAIKey)
                            .textContentType(.password)
                            .autocapitalization(.none)
                    }

                    if isTesting {
                        ProgressView("Testing...")
                    } else {
                        Button("Test API Key") {
                            testOpenAIKey()
                        }
                    }

                    // Show currently used model if set
                    if !openAISelectedModel.isEmpty {
                        HStack {
                            Text("Currently used model:")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(openAISelectedModel)
                                .font(.body)
                                .bold()
                                .foregroundColor(.accentColor)
                        }
                    }

                    if !testResult.isEmpty {
                        Text(testResult)
                            .foregroundColor(testResult.contains("✅") ? .green : .red)
                    }

                    // Manual Model Picker (dynamic, loaded on tap)
                    if !availableModels.isEmpty {
                        // Only show when models are loaded
                        Picker("Preferred Model", selection: $openAISelectedModel) {
                            Text("Auto-Detect").tag("")
                            ForEach(availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    } else {
                        // Only fetch models when user taps to open picker
                        Button("Load Alternative Models") {
                            testOpenAIKey()
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                hubSpotIntegrationSection
                


                autotaskIntegrationSection

              

                if autotaskEnabled {
                    selectDataTypeSection
                }

                additionalSettingsSections
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showHubspotDealPicker) {
                hubspotDealPickerSheet
            }
            .overlay(
                showContactSearch ? contactSelectionOverlay : nil
            )
            .overlay(
                showOpportunitySearch ? opportunitySelectionOverlay : nil
            )
            .overlay(
                showProductSearch ? productSelectionOverlay : nil
            )
        }
    }

    // Extracted Select Data Type Section
    private var selectDataTypeSection: some View {
        Section(header: Text("Select Data Type")) {
            dataTypeButtonsGrid
                .padding()
        }
    }

    // Extracted LazyVGrid of buttons
    private var dataTypeButtonsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(["Company", "Contact", "Opportunity", "Service"], id: \.self) { category in
                dataTypeButton(for: category)
            }
        }
    }

    // Extracted button view
    private func dataTypeButton(for category: String) -> some View {
        Button(action: {
            handleCategorySelection(category)
        }) {
            Text(category)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedCategory == category ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Extracted button action logic
    private func handleCategorySelection(_ category: String) {
        if selectedCategory != category {
            companyName = ""
            searchResults = []
            selectedCompanies.removeAll()
            showContactSearch = false
        }
        selectedCategory = category
    }

    // Extracted additional settings below main grid
    private var additionalSettingsSections: some View {
        Group {
            if !autotaskResult.isEmpty {
                Section(header: Text("Autotask Sync Status")) {
                    Text(autotaskResult)
                        .foregroundColor(
                            autotaskResult.contains("Failed") ||
                            autotaskResult.contains("Error") ||
                            autotaskResult.contains("No companies found")
                            ? .red : .primary
                        )
                }
            }

            if autotaskEnabled {
                searchAndResultsSection
            }
        }
    }

    // Extracted search and results section
    private var searchAndResultsSection: some View {
        Section(header: Text(searchHeaderText)) {
            Group {
                if selectedCategory == "Service" {
                    TextField("Enter service name", text: $companyName, onCommit: {
                        if selectedCategory == "Service" {
                            searchProductsByName()
                        } else {
                            handleSearchCommit()
                        }
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    TextField("Enter company name", text: $companyName, onCommit: handleSearchCommit)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(showOpportunitySearch || showContactSearch)
                }
            }

            if selectedCategory == "Contact" || selectedCategory == "Opportunity" {
                if selectedCompanyID == nil {
                    resultsScrollView  // Display company list for selection
                } else {
                    if selectedCategory == "Contact" {
                        contactSearchField  // Display contact search field after company is selected
                    } else if selectedCategory == "Opportunity" {
                        opportunitySearchField
                            .onAppear {
                                fetchAllOpportunitiesForSelectedCompany()  // Trigger the API call when the view appears
                            }
                    }
                }
            }

            if selectedCategory == "Service" {
                productSearchField
            }

            if selectedCategory == "Company" {
                resultsScrollView  // Display resultsScrollView for Company search
            }

            syncOrImportButton
        }
    }

    // Extracted commit handler
    private func handleSearchCommit() {
        if selectedCategory == "Contact" || selectedCategory == "Opportunity" {
            if !companyName.trimmingCharacters(in: .whitespaces).isEmpty {
                // Only open the overlay for company selection here, do not show the second-level search yet
                searchCompaniesForSelection()
                // Do NOT set showContactSearch or showOpportunitySearch here.
            }
        } else {
            searchCompaniesForSelection()
        }
    }

    // Extracted contact search TextField
    private var contactSearchField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Contacts")
                .font(.headline)
            
            Button(action: { showContactSearch = true }) {
                HStack {
                    Text(selectedContacts.isEmpty ? "Select Contacts" : selectedContacts.map { "\($0.firstName) \($0.lastName)" }.joined(separator: ", "))
                        .foregroundColor(selectedContacts.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
        }
    }


    // Extracted Button for sync/import actions
    @ViewBuilder
    private var syncOrImportButton: some View {
        if selectedCategory == "Company", !selectedCompanies.isEmpty {
            Button("Sync with Autotask now") {
                syncWithAutotask()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        } else if selectedCategory == "Contact", !selectedContacts.isEmpty {
            Button("Sync Contacts now") {
                importSelectedContacts()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        } else if selectedCategory == "Opportunity", !selectedOpportunities.isEmpty && showSyncButton {
            Button("Sync Opportunities now") {
                importSelectedOpportunities()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        } else if selectedCategory == "Service", !selectedProductNames.isEmpty && showSyncButton {
            Button("Sync Products/Services now") {
                importSelectedProducts()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    private func syncWithAutotask() {
        guard !apiUsername.isEmpty, !apiSecret.isEmpty, !apiTrackingID.isEmpty else {
            autotaskResult = "Please enter API credentials and Tracking ID."
            return
        }
        
        isTesting = true
        autotaskResult = "Syncing with Autotask..."
        
        let apiBaseURL = "https://webservices24.autotask.net/ATServicesRest/V1.0/Companies/query"
        var request = URLRequest(url: URL(string: apiBaseURL)!)
        request.httpMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(apiUsername, forHTTPHeaderField: "UserName")
        request.setValue(apiSecret, forHTTPHeaderField: "Secret")
        request.setValue(apiTrackingID, forHTTPHeaderField: "ApiIntegrationCode")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let companyFilters = selectedCompanies.map { company in
            return [
                "op": "contains",
                "field": "companyName",
                "value": company.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            ]
        }
        
        let requestBody: [String: Any] = [
            "MaxRecords": 50,
            "IncludeFields": ["id", "companyName", "address1", "address2", "city", "state", "postalCode", "phone", "webAddress", "companyType"],
            "Filter": [
                [
                    "op": "or",
                    "items": companyFilters
                ]
            ]
        ]
        
        // API Request Payload: \(requestBody)
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            request.httpBody = jsonData
        } catch {
            autotaskResult = "Failed to encode query."
            isTesting = false
            return
        }
        
        // Sending API Request for Companies and formatted API Request Body.
        
        let session = URLSession.shared
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isTesting = false
                if let error = error {
                    autotaskResult = "Sync Failed: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data {
                    // Optionally inspect full API response here.
                    processFetchedCompanies(data)
                } else {
                    autotaskResult = "Failed to authenticate (Unknown status)"
                }
            }
        }.resume()
    }
    
    private func processFetchedCompanies(_ data: Data) {
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            // Selected Companies for Sync.

            if let companies = jsonResponse?["items"] as? [[String: Any]] {
                // Fetched Companies from API.
                
                var companiesToSync: [(name: String, address1: String?, address2: String?, city: String?, state: String?, zipCode: String?, webAddress: String?, companyType: Int?)] = []
                
                for company in companies {
                    if let name = company["companyName"] as? String {
                        let normalizedFetchedName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        let selectedNormalized = selectedCompanies.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }

                        if selectedNormalized.contains(normalizedFetchedName) {
                            let address1 = company["address1"] as? String
                            let address2 = company["address2"] as? String
                            let city = company["city"] as? String
                            let state = company["state"] as? String
                            let zipCode = company["postalCode"] as? String
                            let webAddress = company["webAddress"] as? String
                            let companyType = company["companyType"] as? Int
                            companiesToSync.append((name, address1, address2, city, state, zipCode, webAddress, companyType))
                        }
                    }
                }
                
                if !companiesToSync.isEmpty {
                    CoreDataManager.shared.syncCompaniesFromAutotask(companies: companiesToSync)
                    companyViewModel.fetchCompanies()
                    autotaskResult = "Synced \(companiesToSync.count) companies successfully."
                    resetImportState()
                } else {
                    autotaskResult = "No companies found matching selection."
                }
                selectedCompanies.removeAll()
            } else {
                autotaskResult = "No companies found."
            }
        } catch {
            autotaskResult = "Error parsing data."
        }
    }
    
    private func searchCompaniesForSelection() {
    let trimmedQuery = companyName.trimmingCharacters(in: .whitespaces)
    guard !trimmedQuery.isEmpty else { return }

    if trimmedQuery == "SyncAllCompanyData" {
        AutotaskAPIManager.shared.getAllCompanies { results in
            DispatchQueue.main.async {
                searchResults = results.map { ($0.0, $0.1, "") }
                // Imported all companies.
            }
        }
    } else {
        AutotaskAPIManager.shared.searchCompanies(query: trimmedQuery.lowercased()) { results in
            DispatchQueue.main.async {
                searchResults = results.map { ($0.0, $0.1, "") }
            }
        }
    }
    }

    private func searchCompanyForContacts() {
        let trimmedQuery = companyName.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else { return }

        AutotaskAPIManager.shared.searchCompanies(query: trimmedQuery) { results in
            DispatchQueue.main.async {
                searchResults = results.map { ($0.0, $0.1, "") }
            }
        }
    }

private func searchContactsForCompany() {
    guard let companyID = selectedCompanyID else {
        // No company selected.
        return
    }

    let trimmedContactName = contactName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedContactName.isEmpty else {
        // Contact name is empty.
        return
    }

    let nameComponents = trimmedContactName.split(separator: " ").map(String.init)
    let firstName = nameComponents.first ?? ""
    let lastName = nameComponents.count > 1 ? nameComponents.last ?? "" : ""

    var filterGroup: [String: Any]

    if lastName.isEmpty {
        // Only one name part entered – search by firstName OR lastName
        filterGroup = [
            "op": "and",
            "items": [
                ["op": "eq", "field": "CompanyID", "value": companyID],
                [
                    "op": "or",
                    "items": [
                        ["op": "eq", "field": "firstName", "value": firstName],
                        ["op": "eq", "field": "lastName", "value": firstName]
                    ]
                ]
            ]
        ]
    } else {
        // Two name parts – exact match
        filterGroup = [
            "op": "and",
            "items": [
                ["op": "eq", "field": "CompanyID", "value": companyID],
                ["op": "eq", "field": "firstName", "value": firstName],
                ["op": "eq", "field": "lastName", "value": lastName]
            ]
        ]
    }

    let requestBody: [String: Any] = [
        "MaxRecords": 10,
        "IncludeFields": ["id", "firstName", "lastName", "emailAddress", "phone", "title"],
        "Filter": [filterGroup]
    ]

    // Searching contact with CompanyID, FirstName, LastName.
    // Contact Query Request Body.
    AutotaskAPIManager.shared.searchContactsFromBody(requestBody) { results in
        DispatchQueue.main.async {
            if results.isEmpty {
                // No contacts found for company ID and name.
            } else {
                // Found matching contacts.
                searchResults = results
            }
            showContactSearch = true
        }
    }
}

// MARK: - OpenAI API Key Test
    private func testOpenAIKey() {
        guard !openAIKey.isEmpty else {
            testResult = "❌ Please enter your OpenAI API Key."
            return
        }

        isTesting = true
        testResult = ""

        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isTesting = false
                if let error = error {
                    testResult = "❌ Error: \(error.localizedDescription)"
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let data = data,
                       let modelResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let models = modelResponse["data"] as? [[String: Any]] {
                        // Refined: Only include chat-appropriate models, exclude audio and non-chat models
                        let chatModels = models
                            .compactMap { $0["id"] as? String }
                            .filter {
                                let id = $0.lowercased()
                                return id.contains("gpt") &&
                                       !id.contains("instruct") &&
                                       !id.contains("edit") &&
                                       !id.contains("dall") &&
                                       !id.contains("whisper") &&
                                       !id.contains("tts") &&
                                       !id.contains("audio")
                            }

                        availableModels = chatModels.sorted()

                        let preferredModel = chatModels.first(where: { $0.contains("gpt-4") }) ??
                                             chatModels.first(where: { $0.contains("gpt-3.5") }) ??
                                             chatModels.first

                        if let model = preferredModel {
                            testResult = "✅ OpenAI API Key is valid."
                            if openAISelectedModel.isEmpty {
                                openAIModel = model
                            }
                        } else {
                            testResult = "✅ OpenAI API Key is valid, but no suitable chat model found."
                        }
                    } else {
                        testResult = "✅ OpenAI API Key is valid, but model list could not be parsed."
                        availableModels = []
                    }
                } else {
                    testResult = "❌ Invalid API Key or access error."
                    availableModels = []
                }
            }
        }.resume()
    }

private func importSelectedContacts() {
    guard let selectedCompanyID = selectedCompanyID else {
        print("❌ Missing selected company ID.")
        return
    }
    
    let semaphore = DispatchSemaphore(value: 3)

    let group = DispatchGroup()
    var fetchedContacts: [(firstName: String, lastName: String, email: String?, phone: String?, title: String?)] = []

    for contact in selectedContacts {
        group.enter()
        semaphore.wait()
        
        let requestBody: [String: Any] = [
            "MaxRecords": 1,
            "IncludeFields": ["id", "firstName", "lastName", "emailAddress", "phone", "title"],
            "Filter": [
                [
                    "op": "and",
                    "items": [
                        ["op": "eq", "field": "CompanyID", "value": selectedCompanyID],
                        ["op": "eq", "field": "firstName", "value": contact.firstName],
                        ["op": "eq", "field": "lastName", "value": contact.lastName]
                    ]
                ]
            ]
        ]
        
        AutotaskAPIManager.shared.searchFullContactDetail(requestBody) { contactDetails in
            DispatchQueue.main.async {
                defer {
                    semaphore.signal()
                    group.leave()
                }
                if let details = contactDetails.first {
                    fetchedContacts.append(details)
                } else {
                    // No contact details found for contact.
                }
            }
        }
    }

    group.notify(queue: .main) {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        CoreDataManager.shared.fetchOrCreateCompany(companyID: selectedCompanyID, companyName: companyName) { companyEntity in
            for details in fetchedContacts {
                if let newContact = NSEntityDescription.insertNewObject(forEntityName: "ContactsEntity", into: context) as? ContactsEntity {
                    newContact.id = UUID()
                    newContact.firstName = details.firstName
                    newContact.lastName = details.lastName
                    newContact.emailAddress = details.email
                    newContact.phone = details.phone
                    newContact.title = details.title
                    newContact.companyID = Int64(selectedCompanyID)
                    newContact.company = companyEntity
                }
            }
            
        CoreDataManager.shared.saveContext()
        // Imported contacts successfully.
        selectedContacts.removeAll()
        // Show user confirmation and hide sync button
        autotaskResult = "✅ Imported \(fetchedContacts.count) contacts successfully for company \(companyName)."
        showSyncButton = false
            resetImportState()
        }
    }
}
    private func filterForCompany(_ company: String) -> [String: String] {
        let trimmed = normalizeCompanyName(company)
        return ["op": "contains", "field": "companyName", "value": trimmed]
    }
    
    private func normalizeCompanyName(_ name: String) -> String {
        return name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func handleTap(for result: (Int, String, String)) {
        // handleTap(for:) invoked with result.
        let tappedID = result.0
        let name1 = result.1

        switch selectedCategory {
        case "Company":
            let company = name1
            // Toggle selection logic for multi-select
            if selectedCompanies.contains(company) {
                selectedCompanies.remove(company)
            } else {
                selectedCompanies.insert(company)
            }
            selectedCompanyID = tappedID
            // Attempting to fetch contacts. Current selectedCompanyID.

        case "Contact":
            selectedCompanyID = tappedID
            companyName = name1
            selectedContacts.removeAll()
            searchResults.removeAll()
            fetchAllContactsForSelectedCompany()
            showContactSearch = true

        case "Opportunity":
            selectedCompanyID = tappedID
            showOpportunitySearch = false
            companyName = name1
            selectedOpportunities.removeAll()
            searchResults.removeAll()
            fetchAllOpportunitiesForSelectedCompany()
            showOpportunitySearch = true

        default:
            break
        }
    }
    
    private func handleCompanyTap(_ result: (Int, String, String)) {
        if selectedCompanies.contains(result.1) {
            selectedCompanies.remove(result.1)
        } else {
            selectedCompanies.insert(result.1)
        }
    }

    private func handleContactTap(_ result: (Int, String, String)) {
        let tappedID = result.0
        let contactFirstName = result.1
        let contactLastName = result.2
        let tappedCompanyName = result.1  // use separately for clarity when selecting a company

        if selectedCompanyID == nil || selectedCompanyID != tappedID {
            // This is a company selection during contact search
            selectedCompanyID = tappedID
            companyName = tappedCompanyName
            contactName = ""
            selectedContacts.removeAll()
            searchResults.removeAll()
        } else {
            // This is a contact selection
            contactName = "\(contactFirstName) \(contactLastName)"
            selectedContacts = [Contact(firstName: contactFirstName, lastName: contactLastName)]
            searchResults.removeAll()
        }
    }

    private func contactFromString(_ string: String) -> Contact {
        let nameComponents = string.split(separator: " ").map(String.init)
        return Contact(firstName: nameComponents.first ?? "", lastName: nameComponents.last ?? "")
    }
    
    private func backgroundColor(for result: (Int, String, String)) -> Color {
        let baseColor = Color.blue.opacity(0.3)
        if showContactSearch {
            let contact = Contact(firstName: result.1, lastName: result.2)
            return selectedContacts.contains(contact) ? baseColor : Color.clear
        } else {
            return selectedCompanies.contains(result.1) ? baseColor : Color.clear
        }
    }
    private var contactSelectionOverlay: some View {
        VStack {
            Text("Select Contacts")
                .font(.headline)
                .padding()

            // Search field for contacts
            TextField("Enter contact name", text: $contactName, onCommit: {
                searchContactsForCompany()
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding([.leading, .trailing])
            
            ScrollView {
                LazyVStack {
                    ForEach(searchResults, id: \.0) { result in
                        let contact = Contact(firstName: result.1, lastName: result.2)
                        HStack {
                            Text("\(contact.firstName) \(contact.lastName)")
                            Spacer()
                            if selectedContacts.contains(where: { $0.firstName == contact.firstName && $0.lastName == contact.lastName }) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .onTapGesture {
                            if let index = selectedContacts.firstIndex(where: { $0.firstName == contact.firstName && $0.lastName == contact.lastName }) {
                                selectedContacts.remove(at: index)
                            } else {
                                selectedContacts.append(contact)
                            }
                        }
                    }
                }
            }
            
            Button("Done") {
                showContactSearch = false
                if !selectedContacts.isEmpty {
                    showSyncButton = true
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .frame(width: 600, height: 500)  // Adjusted size for smaller overlay
        .shadow(radius: 20)
        .padding()
        .onAppear {
            fetchAllContactsForSelectedCompany()
        }
    }

    private var resultsScrollView: some View {
        ScrollView {
            LazyVStack {
                ForEach(searchResults, id: \.0) { result in
                    Text("\(result.1) \(result.2)")
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .onTapGesture {
                            handleTap(for: result)
                        }
                        .background(backgroundColor(for: result))
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private func fetchAllContactsForSelectedCompany() {
        // Attempting to fetch contacts. Current selectedCompanyID.
        guard let companyID = selectedCompanyID else {
        // No company selected.
            return
        }
        
        // Fetching contacts for companyID.

        let requestBody: [String: Any] = [
            "MaxRecords": 100,
            "IncludeFields": ["id", "firstName", "lastName"],
            "Filter": [
                [
                    "op": "and",
                    "items": [
                        ["op": "eq", "field": "CompanyID", "value": companyID]
                    ]
                ]
            ]
        ]
        
        // Contact Query Request Body.

        AutotaskAPIManager.shared.searchContactsFromBody(requestBody) { results in
            DispatchQueue.main.async {
                if results.isEmpty {
                    // No contacts found for companyID.
                } else {
                    // Fetched contacts for companyID.
                }
                searchResults = results.map { ($0.0, $0.1, $0.2) }
            }
        }
    }
    // MARK: - Product Search Field
    private var productSearchField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Products / Services")
                .font(.headline)

            Button(action: {
                showProductSearch = true
                fetchAllProductsFromAutotask()
            }) {
                HStack {
                    Text(selectedProductNames.isEmpty ? "Select Services" :
                        selectedProductNames.joined(separator: ", "))
                        .foregroundColor(selectedProductNames.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
        }
    }

    // MARK: - Product Name Search (for Product category)
    private func searchProductsByName() {
        let trimmedQuery = companyName.trimmingCharacters(in: .whitespaces)

        let filterGroup: [String: Any]
        if trimmedQuery.isEmpty {
            filterGroup = [
                "op": "exist",
                "field": "id"
            ]
        } else {
            filterGroup = [
                "op": "and",
                "items": [
                    ["op": "contains", "field": "name", "value": trimmedQuery]
                ]
            ]
        }

        // Product search filter.

        let requestBody: [String: Any] = [
            "MaxRecords": 100,
            "IncludeFields": [
                "id", "name", "description", "invoiceDescription", "unitCost",
                "unitPrice", "sku", "catalogNumberPartNumber", "lastModifiedDate"
            ],
            "Filter": [filterGroup]
        ]

        let completionBlock: ([(Int, String, String, Double, Double, String, String, Date?)]) -> Void = { results in
            DispatchQueue.main.async {
                // Use $0.2 for description so both product name and description are available/displayed.
                productSearchResults = results.map { ($0.0, $0.1, $0.2) }
                productImportCache = results.map { tuple in
                    let (id, name, description, unitCost, unitPrice, invoiceDescription, _, lastModifiedDate) = tuple
                    return (
                        id,
                        name,                   // name -> name
                        description,            // description -> prodDescription
                        invoiceDescription,     // invoiceDescription -> benefits
                        unitCost,               // unitCost -> unitCost
                        unitPrice,              // unitPrice -> unitPrice
                        lastModifiedDate        // lastModifiedDate
                    )
                }
                showProductSearch = true
            }
        }
        AutotaskAPIManager.shared.searchServicesFromBody(requestBody, completion: completionBlock)
    }

    // MARK: - Product Selection Overlay
    private var productSelectionOverlay: some View {
        VStack {
            Text("Select Services")
                .font(.headline)
                .padding()

            ScrollView {
                LazyVStack {
                    ForEach(productSearchResults, id: \.0) { result in
                        // result: (Int, String, String)
                        HStack {
                            VStack(alignment: .leading) {
                                Text(result.1).bold() // Product Name
                                Text("Description: \(result.2)").font(.subheadline).foregroundColor(.gray)
                                // Try to get the invoice description from productImportCache
                                if let idx = productImportCache.firstIndex(where: { $0.0 == result.0 && $0.1 == result.1 }) {
                                    let invoiceDescription = productImportCache[idx].3
                                    Text("Invoice Description: \(invoiceDescription)").font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if selectedProductNames.contains(result.1) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .onTapGesture {
                            if selectedProductNames.contains(result.1) {
                                selectedProductNames.remove(result.1)
                            } else {
                                selectedProductNames.insert(result.1)
                            }
                        }
                    }
                }
            }

            Button("Done") {
                showProductSearch = false
                if !selectedProductNames.isEmpty {
                    showSyncButton = true
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .frame(width: 600, height: 500)
        .shadow(radius: 20)
        .padding()
        // Removed .onAppear { fetchAllProductsFromAutotask() }
    }

    // MARK: - Import Selected Products
    private func importSelectedProducts() {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        let semaphore = DispatchSemaphore(value: 3)
        let group = DispatchGroup()

        for name in selectedProductNames {
            group.enter()
            semaphore.wait()
            DispatchQueue.global().async {
                if let cached = productImportCache.first(where: { $0.1 == name }), !cached.1.isEmpty {
                    let fetchRequest: NSFetchRequest<ProductEntity> = ProductEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "autotaskID == %lld", Int64(cached.0))
                    let existingProduct = try? context.fetch(fetchRequest).first
                    if let existingProduct = existingProduct {
                        // Update existing product
                        existingProduct.type = "Service"
                        existingProduct.units = "Per Device"
                        existingProduct.prodDescription = cached.2
                        existingProduct.benefits = cached.3
                        existingProduct.unitCost = cached.4 ?? 0.0
                        existingProduct.unitPrice = cached.5 ?? 0.0
                        existingProduct.lastModified = cached.6
                    } else {
                        // Create new product
                        guard !cached.1.isEmpty else {
                            // Skipping product with missing name.
                            DispatchQueue.main.async {
                                semaphore.signal()
                                group.leave()
                            }
                            return
                        }
                        let newProduct = ProductEntity(context: context)
                        newProduct.autotaskID = Int64(cached.0)
                        newProduct.name = cached.1
                        newProduct.type = "Service"
                        newProduct.units = "Per Device"
                        newProduct.prodDescription = cached.2
                        newProduct.benefits = cached.3
                        newProduct.unitCost = cached.4 ?? 0.0
                        newProduct.unitPrice = cached.5 ?? 0.0
                        newProduct.lastModified = cached.6
                    }
                } else {
                    // Skipping product with missing or unmatched cache entry.
                    DispatchQueue.main.async {
                        semaphore.signal()
                        group.leave()
                    }
                    return
                }

                DispatchQueue.main.async {
                    semaphore.signal()
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            CoreDataManager.shared.saveContext()
            autotaskResult = "✅ Imported \(selectedProductNames.count) products/services successfully."
            selectedProductNames.removeAll()
            showSyncButton = false
            resetImportState()
        }
    }

    private func fetchAllProductsFromAutotask() {
        let requestBody: [String: Any] = [
            "MaxRecords": 100,
            "IncludeFields": ["id", "name", "description", "invoiceDescription", "unitCost", "unitPrice", "lastModifiedDate"],
            "Filter": [
                [
                    "op": "exist",
                    "field": "id"
                ]
            ]
        ]

        let completionBlock: ([(Int, String, String, Double, Double, String, String, Date?)]) -> Void = { results in
            DispatchQueue.main.async {
                if results.isEmpty {
                    // No products/services found.
                } else {
                    // Retrieved products/services.
                }
                productSearchResults = results.map { ($0.0, $0.1, $0.2) }
                productImportCache = results.map { tuple in
                    let (id, name, description, unitCost, unitPrice, invoiceDescription, _, lastModifiedDate) = tuple
                    return (
                        id,
                        name,                   // name -> name
                        description,            // description -> prodDescription
                        invoiceDescription,     // invoiceDescription -> benefits
                        unitCost,               // unitCost -> unitCost
                        unitPrice,              // unitPrice -> unitPrice
                        lastModifiedDate        // lastModifiedDate
                    )
                }
            }
        }
        AutotaskAPIManager.shared.searchServicesFromBody(requestBody, completion: completionBlock)
    }
}
 




struct OpenAIHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("OpenAI API Setup Instructions")
                    .font(.title2)
                    .bold()

                Text("1. Create an OpenAI account at [https://platform.openai.com/](https://platform.openai.com/).")
                Text("2. Go to your API Keys page after logging in.")
                Text("3. Click 'Create new secret key' and name it for your reference (e.g., SalesDiver).")
                Text("4. Copy and store the key safely. You won’t be able to see it again.")
                Text("5. Enter your key in the SalesDiver settings under 'OpenAI API Key'.")
                Text("6. Click 'Test API Key' to verify and load available models.")
                Text("A paid OpenAI account is required to access the GPT-4 and GPT-3.5 APIs.")
            }
            .padding()
        }
        .navigationTitle("OpenAI Help")
    }
}

struct AutotaskHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Autotask API Setup Instructions")
                    .font(.title2)
                    .bold()

                Group {
                    Text("1. Log in to Autotask: Access your Autotask account using your credentials.")
                    Text("2. Navigate to Admin > Resources/Users: Go to the Admin section and select Resources/Users.")
                    Text("3. Create New API User: Click the 'New' button and then select 'New API User' from the dropdown menu.")
                    Text("4. Fill in Required Fields:")
                    Text("    - First Name, Last Name, Email Address: Enter the basic information for the API user.")
                    Text("    - Security Level: Choose 'API User (System)'.")
                    Text("    - Username and Password: Generate a unique username and password or use the 'Generate' button.")
                    Text("      Note: The password must meet the criteria configured in your Autotask system settings.")
                    Text("5. For API Tracking Identifier, choose 'Custom' and enter: SalesDiver")
                    Text("6. Please store the username, password (secret), and Tracking Identifier securely.")
                    Text("You will need all three to connect SalesDiver with Autotask.")
                }
            }
            .padding()
        }
        .navigationTitle("Autotask Help")
    }
}

// MARK: - HubSpot UI Models
/// A small, public, UI-friendly model so SettingsView does not depend on private API response types.
struct HubSpotDealSummary: Identifiable, Hashable {
    let id: String
    let name: String
}



