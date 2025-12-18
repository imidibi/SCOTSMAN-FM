import SwiftUI
import CoreData

struct ClientAssessmentsHubView: View {
    // Core Data companies
    @FetchRequest(
        entity: CompanyEntity.entity(),
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)]
    ) private var companies: FetchedResults<CompanyEntity>

    @State private var selectedCompany: CompanyEntity? = nil
    @State private var showTemplatePicker: Bool = false
    @State private var templates: [AssessmentDefinition] = []
    @State private var companyResponses: [AssessmentResponse] = []
    @State private var path = NavigationPath()

    private var selectedCompanyObjectIDBinding: Binding<NSManagedObjectID?> {
        Binding<NSManagedObjectID?>(
            get: { selectedCompany?.objectID },
            set: { newID in
                if let id = newID {
                    selectedCompany = companies.first(where: { $0.objectID == id })
                    reloadResponses()
                } else {
                    selectedCompany = nil
                    companyResponses = []
                }
            }
        )
    }

    enum Destination: Hashable {
        case new(definition: AssessmentDefinition, companyID: String)
        case edit(definition: AssessmentDefinition, companyID: String, response: AssessmentResponse)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Select Company") {
                    Picker("Company", selection: selectedCompanyObjectIDBinding) {
                        Text("Choose…").tag(nil as NSManagedObjectID?)
                        ForEach(companies, id: \.objectID) { company in
                            Text(company.name ?? "(Unnamed)")
                                .tag(company.objectID as NSManagedObjectID?)
                        }
                    }
                }

                if let _ = selectedCompany {
                    Section(header: Text("Existing Assessments")) {
                        if companyResponses.isEmpty {
                            Text("No saved assessments for this company")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(companyResponses) { resp in
                                Button {
                                    let def = dummyDefinitionFor(resp)
                                    path.append(Destination.edit(definition: def, companyID: companyIDString, response: resp))
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(resp.assessmentTitle)
                                            .font(.headline)
                                        Text(resp.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Button {
                            showTemplatePicker = true
                        } label: {
                            Label("New Assessment", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
            .navigationTitle("Client Assessments")
            .onAppear {
                templates = AssessmentStorage.loadAll()
            }
            .sheet(isPresented: $showTemplatePicker) {
                NavigationStack {
                    AssessmentTemplatePickerView(templates: templates) { template in
                        showTemplatePicker = false
                        guard let company = selectedCompany else { return }
                        let companyID = company.objectID.uriRepresentation().absoluteString
                        let dest = Destination.new(definition: template, companyID: companyID)
                        path.append(dest)
                    }
                }
            }
            .navigationDestination(for: Destination.self) { dest in
                switch dest {
                case let .new(definition, companyID):
                    DynamicAssessmentView(definition: definition, companyID: companyID)
                case let .edit(definition, companyID, response):
                    DynamicAssessmentView(definition: definition, companyID: companyID, existingResponse: response)
                }
            }
        }
    }

    private var companyIDString: String {
        selectedCompany?.objectID.uriRepresentation().absoluteString ?? ""
    }

    private func reloadResponses() {
        guard let company = selectedCompany else {
            companyResponses = []
            return
        }
        let id = company.objectID.uriRepresentation().absoluteString
        companyResponses = AssessmentResponseStorage.loadAll(forCompanyID: id)
    }

    // We need a definition when deep-linking into an existing response. If you want to strictly
    // use the definition that matches resp.assessmentID, you can look it up from disk. For now,
    // we provide a lightweight lookup by title, falling back to an empty shell if not found.
    private func dummyDefinitionFor(_ resp: AssessmentResponse) -> AssessmentDefinition {
        let defs = AssessmentStorage.loadAll()
        if let match = defs.first(where: { $0.id == resp.assessmentID || $0.title == resp.assessmentTitle }) {
            return match
        }
        return AssessmentDefinition(id: resp.assessmentID, title: resp.assessmentTitle, sections: [])
    }
}

// A tiny wrapper to expose a template picker with a completion handler
struct AssessmentTemplatePickerView: View {
    let templates: [AssessmentDefinition]
    let onPick: (AssessmentDefinition) -> Void

    var body: some View {
        List {
            ForEach(templates) { def in
                Button {
                    onPick(def)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                        Text(def.title)
                    }
                }
            }
        }
        .navigationTitle("Choose Template")
    }
}
