import SwiftUI
import CoreData

struct NewFollowUpView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CompanyEntity.name, ascending: true)],
        animation: .default)
    private var companies: FetchedResults<CompanyEntity>

    @State private var selectedCompany: CompanyEntity?
    @State private var selectedOpportunity: OpportunityEntity?
    @State private var name: String = ""
    @State private var assignedTo: String = ""
    @State private var dueDate: Date = Date()
    @State private var completed: Bool = false
    @State private var searchText: String = ""
    @State private var showingOpportunitySheet: Bool = false

    var body: some View {
        Form {
            companyPicker
            opportunityPicker
            followUpDetails
            saveSection
        }
        .navigationTitle("New Follow Up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredCompanies: [CompanyEntity] {
        companies.filter {
            searchText.isEmpty || ($0.name?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var companyPicker: some View {
        Section(header: Text("Select Company")) {
            Picker("Company", selection: $selectedCompany) {
                Text("None").tag(nil as CompanyEntity?)
                ForEach(filteredCompanies, id: \.self) { company in
                    Text(company.name ?? "Unknown").tag(company as CompanyEntity?)
                }
            }
            TextField("Search Company", text: $searchText)
        }
    }

    private var opportunityPicker: some View {
        Section(header: Text("Select Opportunity")) {
            if let company = selectedCompany {
                let opportunities = getOpportunities(for: company)

                Button(action: {
                    showingOpportunitySheet = true
                }) {
                    HStack {
                        Text("Opportunity")
                        Spacer()
                        Text(selectedOpportunity?.name ?? "None")
                            .foregroundColor(.gray)
                    }
                }
                .sheet(isPresented: $showingOpportunitySheet) {
                    NavigationView {
                        List {
                            ForEach(opportunities, id: \.self) { opportunity in
                                Button(action: {
                                    selectedOpportunity = opportunity
                                    showingOpportunitySheet = false
                                }) {
                                    Text(opportunity.name ?? "Untitled")
                                }
                            }
                        }
                        .navigationTitle("Choose Opportunity")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showingOpportunitySheet = false
                                }
                            }
                        }
                    }
                }
            } else {
                Text("Select a company first to see opportunities.")
            }
        }
    }

    private func getOpportunities(for company: CompanyEntity) -> [OpportunityEntity] {
        company.opportunities?.allObjects as? [OpportunityEntity] ?? []
    }

    private var followUpDetails: some View {
        Section(header: Text("Follow Up Details")) {
            TextField("Name", text: $name)
            TextField("Assigned To", text: $assignedTo)
            DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
            Toggle("Completed", isOn: $completed)
        }
    }

    private var saveSection: some View {
        Section {
            Button("Save") {
                saveFollowUp()
            }
        }
    }

    private func saveFollowUp() {
        let newFollowUp = FollowUpsEntity(context: viewContext)
        newFollowUp.name = name
        newFollowUp.assignedTo = assignedTo
        newFollowUp.dueDate = dueDate
        newFollowUp.completed = completed
        newFollowUp.id = UUID()
        newFollowUp.opportunity = selectedOpportunity

        do {
            try viewContext.save()
            dismiss()
        } catch {
            // print("Failed to save follow-up: \(error.localizedDescription)")
        }
    }
}

struct FollowUpsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FollowUpsEntity.dueDate, ascending: true)],
        animation: .default)
    private var followUps: FetchedResults<FollowUpsEntity>

    @AppStorage("selectedMethodology") private var currentMethodology: String = "BANT"

    @State private var showingNewFollowUp = false
    @State private var selectedFollowUp: FollowUpsEntity?
    @State private var searchText: String = ""

    var body: some View {
        List {
            ForEach(followUps.filter { followUp in
                searchText.isEmpty ||
                (followUp.opportunity?.company?.name?.localizedCaseInsensitiveContains(searchText) == true) ||
                (followUp.opportunity?.name?.localizedCaseInsensitiveContains(searchText) == true) ||
                (followUp.assignedTo?.localizedCaseInsensitiveContains(searchText) == true)
            }) { followUp in
                HStack {
                    VStack(alignment: .leading) {
                        Text(followUp.name ?? "Untitled")
                            .font(.headline)
                            .foregroundColor(followUp.completed ? .green : .blue)
                        Text("Assigned to: \(followUp.assignedTo ?? "N/A")")
                            .font(.subheadline)
                        Text("Due: \(followUp.dueDate ?? Date(), formatter: dateFormatter)")
                            .font(.subheadline)
                            .foregroundColor((followUp.dueDate ?? Date()) < Date() ? .red : .primary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(followUp.opportunity?.company?.name ?? "No Company")
                            .font(.headline)
                        Text(followUp.opportunity?.name ?? "No Opportunity")
                            .font(.subheadline)
                        if let opportunity = followUp.opportunity {
                            indicatorView(for: opportunity)
                        }
                    }
                }
                .onTapGesture {
                    selectedFollowUp = followUp
                }
            }
            .onDelete(perform: deleteFollowUp)
        }
        .navigationTitle("Follow Ups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingNewFollowUp.toggle() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by company, opportunity, or assignee")
        .sheet(isPresented: $showingNewFollowUp) {
            NavigationView {
                AddFollowUpView()
            }
        }
        .sheet(item: $selectedFollowUp) { followUp in
            NavigationView {
                EditFollowUpView(followUp: followUp)
            }
        }
    }

    @ViewBuilder
    private func indicatorView(for opportunity: OpportunityEntity) -> some View {
        let wrapper = OpportunityWrapper(managedObject: opportunity)
        if currentMethodology == "BANT" {
            BANTIndicatorView(opportunity: wrapper, onBANTSelected: { _ in })
        } else if currentMethodology == "MEDDIC" {
            MEDDICIndicatorView(opportunity: wrapper, onMEDDICSelected: { _ in })
        } else if currentMethodology == "SCUBATANK" {
            SCUBATANKIndicatorView(opportunity: wrapper, onSCUBATANKSelected: { _ in })
        } else {
            EmptyView()
        }
    }

    private func deleteFollowUp(at offsets: IndexSet) {
        for index in offsets {
            let followUp = followUps[index]
            viewContext.delete(followUp)
        }
        try? viewContext.save()
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return formatter
}()


extension Binding {
    init(_ source: Binding<Value?>, replacingNilWith defaultValue: Value) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { newValue in source.wrappedValue = newValue }
        )
    }
}
