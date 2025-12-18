import SwiftUI

struct EditFollowUpView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var followUp: FollowUpsEntity
    @State private var emailBodyText = ""
    @State private var isShowingEmailDraft = false

    @State private var isShowingCompanyPicker = false
    @State private var isShowingOpportunityPicker = false
    @State private var selectedCompany: CompanyEntity?
    @State private var selectedOpportunity: OpportunityEntity?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Follow Up Details")) {
                    TextField("Name", text: Binding(
                        get: { followUp.name ?? "" },
                        set: { followUp.name = $0 }
                    ))
                    TextField("Assigned To", text: Binding(
                        get: { followUp.assignedTo ?? "" },
                        set: { followUp.assignedTo = $0 }
                    ))
                    DatePicker("Due Date", selection: Binding(
                        get: { followUp.dueDate ?? Date() },
                        set: { followUp.dueDate = $0 }
                    ), displayedComponents: .date)
                    Toggle("Completed", isOn: Binding(
                        get: { followUp.completed },
                        set: { followUp.completed = $0 }
                    ))
                }

                Section(header: Text("Related Company & Opportunity")) {
                    Button(action: { isShowingCompanyPicker = true }) {
                        HStack {
                            Text("Company")
                            Spacer()
                            Text(selectedCompany?.name ?? followUp.opportunity?.company?.name ?? "Select")
                                .foregroundColor(.gray)
                        }
                    }
                    Button(action: { isShowingOpportunityPicker = true }) {
                        HStack {
                            Text("Opportunity")
                            Spacer()
                            Text(selectedOpportunity?.name ?? followUp.opportunity?.name ?? "Select")
                                .foregroundColor(.gray)
                        }
                    }
                }

                Button("Save") {
                    if let selectedOpportunity = selectedOpportunity {
                        followUp.opportunity = selectedOpportunity
                    }
                    do {
                        try viewContext.save()
                        dismiss()
                    } catch {
                        // print("Failed to save follow-up: \(error.localizedDescription)")
                    }
                }

                Button("Save and Email") {
                    if let selectedOpportunity = selectedOpportunity {
                        followUp.opportunity = selectedOpportunity
                    }
                    do {
                        try viewContext.save()
                        isShowingEmailDraft = true
                    } catch {
                        // print("Failed to save follow-up: \(error.localizedDescription)")
                    }
                }
                .disabled((followUp.assignedTo ?? "").isEmpty)

                Button("Cancel", role: .cancel) {
                    viewContext.rollback()
                    dismiss()
                }
            }
            .navigationTitle("Edit Follow Up")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingEmailDraft) {
                EmailDraftView(
                    contactEmail: followUp.assignedTo ?? "",
                    contactFirstName: followUp.assignedTo?.components(separatedBy: " ").first ?? "there",
                    subject: "Follow Up: \(followUp.name ?? "")",
                    companyName: followUp.opportunity?.company?.name ?? "",
                    opportunityName: followUp.opportunity?.name ?? "",
                    followUpName: followUp.name ?? "",
                    dueDate: followUp.dueDate ?? Date(),
                    emailText: $emailBodyText,
                    isPresented: $isShowingEmailDraft
                )
            }
            .sheet(isPresented: $isShowingCompanyPicker) {
                CompanySearchView(isPresented: $isShowingCompanyPicker) { company in
                    selectedCompany = company
                }
            }
            .sheet(isPresented: $isShowingOpportunityPicker) {
                if let company = selectedCompany ?? followUp.opportunity?.company {
                    OpportunitySearchView(company: company, isPresented: $isShowingOpportunityPicker) { opportunity in
                        selectedOpportunity = opportunity
                        followUp.opportunity = opportunity
                    }
                } else {
                    Text("Please select a company first.")
                }
            }
        }
    }
}

struct CompanySearchView: View {
    @Binding var isPresented: Bool
    var onSelect: (CompanyEntity) -> Void
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CompanyEntity.name, ascending: true)],
        animation: .default)
    private var companies: FetchedResults<CompanyEntity>

    var body: some View {
        NavigationView {
            List {
                ForEach(companies, id: \.self) { company in
                    Button(company.name ?? "Unnamed") {
                        onSelect(company)
                        isPresented = false
                    }
                }
            }
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

struct OpportunitySearchView: View {
    var company: CompanyEntity
    @Binding var isPresented: Bool
    var onSelect: (OpportunityEntity) -> Void

    var body: some View {
        NavigationView {
            let opportunities = company.opportunities?.allObjects as? [OpportunityEntity] ?? []
            List {
                ForEach(opportunities, id: \.self) { opportunity in
                    Button(opportunity.name ?? "Unnamed") {
                        onSelect(opportunity)
                        isPresented = false
                    }
                }
            }
            .navigationTitle("Select Opportunity")
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
