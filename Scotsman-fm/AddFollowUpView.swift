import SwiftUI
import CoreData

struct AddFollowUpView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCompany: CompanyEntity?
    @State private var selectedOpportunity: OpportunityEntity?
    @State private var showingOpportunitySheet: Bool = false

    @State private var name: String = ""
    @State private var assignedTo: String = ""
    @State private var assignedEmail: String = ""
    @State private var dueDate: Date = .now
    @State private var completed: Bool = false
    @State private var searchText: String = ""
    @State private var isShowingContactPicker: Bool = false
    @State private var isShowingCompanyPicker: Bool = false
    @State private var isShowingOpportunityPicker: Bool = false
    @State private var isShowingEmailDraft: Bool = false
    @State private var emailBodyText: String = ""

    @FetchRequest(entity: CompanyEntity.entity(), sortDescriptors: []) var companies: FetchedResults<CompanyEntity>
    @FetchRequest(entity: ContactsEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \ContactsEntity.lastName, ascending: true)]) var contacts: FetchedResults<ContactsEntity>

    var body: some View {
        NavigationStack {
            Form {
                companySection
                opportunitySection
                detailsSection
                saveButtonSection
            }
            .navigationTitle("New Follow Up")
        }
        .sheet(isPresented: $isShowingContactPicker) {
            ContactPickerSheetView(
                assignedTo: $assignedTo,
                assignedEmail: $assignedEmail,
                isPresented: $isShowingContactPicker,
                contacts: contacts
            )
        }
        .sheet(isPresented: $isShowingCompanyPicker) {
            CompanyPickerSheetView(
                companies: companies,
                selectedCompany: $selectedCompany,
                selectedOpportunity: $selectedOpportunity,
                isPresented: $isShowingCompanyPicker
            )
        }
        .sheet(isPresented: $isShowingOpportunityPicker) {
            if let company = selectedCompany {
                let opportunities = company.opportunities?.allObjects as? [OpportunityEntity] ?? []
                NavigationView {
                    List {
                        ForEach(opportunities, id: \.self) { opportunity in
                            Button(action: {
                                selectedOpportunity = opportunity
                                isShowingOpportunityPicker = false
                            }) {
                                Text(opportunity.name ?? "Untitled")
                            }
                        }
                    }
                    .navigationTitle("Select Opportunity")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isShowingOpportunityPicker = false
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingEmailDraft, onDismiss: {
            resetForm()
        }) {
            EmailDraftView(
                contactEmail: assignedEmail,
                contactFirstName: assignedTo.components(separatedBy: " ").first ?? "there",
                subject: "Follow Up: \(name)",
                companyName: selectedCompany?.name ?? "",
                opportunityName: selectedOpportunity?.name ?? "",
                followUpName: name,
                dueDate: dueDate,
                emailText: $emailBodyText,
                isPresented: $isShowingEmailDraft
            )
        }
    }

    private var companySection: some View {
        Section(header: Text("Select Company")) {
            Button(action: {
                isShowingCompanyPicker = true
            }) {
                HStack {
                    Text("Company")
                    Spacer()
                    Text(selectedCompany?.name ?? "None")
                        .foregroundColor(.gray)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    @ViewBuilder
    private var opportunitySection: some View {
        if selectedCompany != nil {
            Section(header: Text("Select Opportunity")) {
                Button(action: {
                    isShowingOpportunityPicker = true
                }) {
                    HStack {
                        Text("Opportunity")
                        Spacer()
                        Text(selectedOpportunity?.name ?? "None")
                            .foregroundColor(.gray)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private var detailsSection: some View {
        Group {
            Section(header: Text("Follow Up Details")) {
                TextField("Name", text: $name)
            }
            // Explicitly use a Button row for "Assigned To" and force SwiftUI to treat as button, not TextField
            Section {
                Button(action: {
                    // print("Tapped Assigned To")
                    isShowingContactPicker = true
                }) {
                    HStack {
                        Text("Assigned To")
                        Spacer()
                        Text(assignedTo.isEmpty ? "Select Contact" : assignedTo)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            Section {
                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                Toggle("Completed", isOn: $completed)
            }
        }
    }

    private var saveButtonSection: some View {
        Section {
            Button("Save") {
                saveFollowUp(dismissAfterSave: true)
            }
            Button("Save and Email") {
                // print("DEBUG — Save and Email:")
                // print("Assigned To: \(assignedTo)")
                // print("Email: \(assignedEmail)")
                // print("Company: \(selectedCompany?.name ?? "nil")")
                // print("Opportunity: \(selectedOpportunity?.name ?? "nil")")
                // print("Follow-Up Name: \(name)")
                
                saveFollowUp(dismissAfterSave: false)
                emailBodyText = "" // Clear email body before presenting draft
                isShowingEmailDraft = true
            }
            .disabled(assignedEmail.isEmpty)
        }
    }
    
    private func saveFollowUp(dismissAfterSave: Bool = true) {
        let newFollowUp = FollowUpsEntity(context: viewContext)
        // newFollowUp.company = selectedCompany // Removed as relationship is established via selectedOpportunity
        newFollowUp.opportunity = selectedOpportunity
        newFollowUp.name = name
        newFollowUp.assignedTo = assignedTo
        newFollowUp.dueDate = dueDate
        newFollowUp.completed = completed
        newFollowUp.id = UUID()

        do {
            try viewContext.save()
            if dismissAfterSave {
                resetForm()
                dismiss()
            }
        } catch {
            // print("Save failed: \(error.localizedDescription)")
        }
    }

    private func resetForm() {
        name = ""
        assignedTo = ""
        assignedEmail = ""
        dueDate = Date()
        completed = false
        selectedCompany = nil
        selectedOpportunity = nil
    }

    private func createEmailUrl(to: String, subject: String, body: String) -> URL? {
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "mailto:\(to)?subject=\(subjectEncoded)&body=\(bodyEncoded)"
        return URL(string: urlString)
    }
}

private struct ContactPickerView: View {
    @Binding var assignedTo: String
    @Binding var assignedEmail: String
    @Binding var isPresented: Bool
    let contacts: FetchedResults<ContactsEntity>

    @State private var searchText: String = ""

    private var filteredContacts: [ContactsEntity] {
        if searchText.isEmpty {
            return Array(contacts)
        } else {
            return contacts.filter {
                ($0.firstName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.lastName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        List {
            ForEach(filteredContacts, id: \.objectID) { contact in
                Button(action: {
                    assignedTo = "\(contact.firstName ?? "") \(contact.lastName ?? "")"
                    assignedEmail = contact.emailAddress ?? ""
                    isPresented = false
                }) {
                    contactRow(for: contact)
                }
            }
        }
        .searchable(text: $searchText)
    }

    private func contactRow(for contact: ContactsEntity) -> some View {
        VStack(alignment: .leading) {
            Text("\(contact.firstName ?? "") \(contact.lastName ?? "")")
            Text(contact.emailAddress ?? "")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

private struct ContactPickerSheetView: View {
    @Binding var assignedTo: String
    @Binding var assignedEmail: String
    @Binding var isPresented: Bool
    let contacts: FetchedResults<ContactsEntity>

    @State private var searchText: String = ""

    private var filteredContacts: [ContactsEntity] {
        if searchText.isEmpty {
            return Array(contacts)
        } else {
            return contacts.filter {
                ($0.firstName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.lastName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredContacts, id: \.objectID) { contact in
                    Button(action: {
                        assignedTo = "\(contact.firstName ?? "") \(contact.lastName ?? "")"
                        assignedEmail = contact.emailAddress ?? ""
                        isPresented = false
                    }) {
                        VStack(alignment: .leading) {
                            Text("\(contact.firstName ?? "") \(contact.lastName ?? "")")
                            Text(contact.emailAddress ?? "")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Select Contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

private struct CompanyPickerSheetView: View {
    let companies: FetchedResults<CompanyEntity>
    @Binding var selectedCompany: CompanyEntity?
    @Binding var selectedOpportunity: OpportunityEntity?
    @Binding var isPresented: Bool

    @State private var searchText: String = ""

    private var filteredCompanies: [CompanyEntity] {
        if searchText.isEmpty {
            return Array(companies)
        } else {
            return companies.filter {
                $0.name?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredCompanies, id: \.self) { company in
                    Button(action: {
                        selectedCompany = company
                        selectedOpportunity = nil
                        isPresented = false
                    }) {
                        Text(company.name ?? "Unknown")
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Select Company")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
