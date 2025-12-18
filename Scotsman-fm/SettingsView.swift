import CoreData
import SwiftUI

struct Contact: Hashable {
    let firstName: String
    let lastName: String
}

struct SettingsView: View {
    @ObservedObject var companyViewModel: CompanyViewModel
    @AppStorage("disableBubbleAnimation") private var disableBubbleAnimation: Bool = false
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
                        Text("SCUBATANK").tag("SCUBATANK")
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

                autotaskIntegrationSection

                if autotaskEnabled {
                    selectDataTypeSection
                }

                additionalSettingsSections
                
                Section {
                    Toggle("Turn off bubble animations", isOn: $disableBubbleAnimation)
                }
            }
            .navigationTitle("Settings")
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


// MARK: - Help Views

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
