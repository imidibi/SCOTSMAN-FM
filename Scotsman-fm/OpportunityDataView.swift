//
//  OpportunityDataView.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//

import SwiftUI
import CoreData

struct SelectedBANTItem: Identifiable {
    var id: NSManagedObjectID { opportunity.id }
    var opportunity: OpportunityWrapper
    var bantType: BANTIndicatorView.BANTType
}

// New struct for non-BANT qualification item selection
struct SelectedQualificationItem: Identifiable, Equatable {
    var id: NSManagedObjectID { opportunity.id }
    var opportunity: OpportunityWrapper
    var qualificationType: String

    static func == (lhs: SelectedQualificationItem, rhs: SelectedQualificationItem) -> Bool {
        lhs.opportunity.id == rhs.opportunity.id && lhs.qualificationType == rhs.qualificationType
    }
}

enum OpportunitySortOption: String, CaseIterable {
    case companyName = "Company Name"
    case productName = "Service Name"
    case closeDate = "Close Date"
}

struct OpportunitySummaryView: View {
    let opportunity: OpportunityWrapper

    var body: some View {
        VStack(alignment: .leading) {

            Text("Company: \(opportunity.companyName)")
                .foregroundColor(.gray)

            Text("Close Date: \(opportunity.closeDate, style: .date)")

            if let serviceText = serviceNameText {
                Text("Service: \(serviceText)")
                    .foregroundColor(.gray)
            }

            Text("Probability: \(opportunity.probability)%")
            Text("Monthly Revenue: $\(opportunity.monthlyRevenue, specifier: "%.2f")")
            Text("One-Time Revenue: $\(opportunity.onetimeRevenue, specifier: "%.2f")")
            Text("Estimated Value: $\(opportunity.estimatedValue, specifier: "%.2f")")

            Text("Status: \(statusText)")
                .foregroundColor(statusColor)
        }
    }

    private var serviceNameText: String? {
        let trimmed = opportunity.productName.trimmingCharacters(in: .whitespacesAndNewlines)
        return (!trimmed.isEmpty && trimmed.lowercased() != "unknown product") ? trimmed : nil
    }

    private var statusText: String {
        switch opportunity.status {
        case 1: return "Active"
        case 2: return "Lost"
        case 3: return "Closed"
        default: return "Unknown"
        }
    }

    private var statusColor: Color {
        switch opportunity.status {
        case 1: return .blue
        case 2: return .red
        case 3: return .green
        default: return .gray
        }
    }
}

struct OpportunityDataView: View {
    @ObservedObject var viewModel = OpportunityViewModel()
    
    @AppStorage("selectedMethodology") private var currentMethodology: String = "BANT"
    
    @State private var searchText: String = ""  // ✅ Search state
    @State private var sortOption: OpportunitySortOption = .companyName  // ✅ Default sorting

    @State private var selectedBANTItem: SelectedBANTItem? = nil  // Combined state for BANT Editing
    @State private var selectedQualificationItem: SelectedQualificationItem? = nil // State for non-BANT items
    @State private var editingOpportunity: OpportunityWrapper?   // ✅ Used for Opportunity Editing
    @State private var isPresentingAddOpportunity = false  // ✅ Added state for modal
    @State private var isPresentingEditOpportunity = false // ✅ Added state for editing
    @State private var isPresentingAIGuidance = false
    @State private var aiGuidanceText: String = ""
    @State private var isPresentingHelp = false

    var filteredOpportunities: [OpportunityWrapper] {
        // print("Rebuilding filtered opportunities: \(viewModel.opportunities.map { $0.id })")
        var opportunities = viewModel.opportunities

        // 🔍 Filter by search text
        if !searchText.isEmpty {
            opportunities = opportunities.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // 🔄 Apply sorting
        switch sortOption {
        case .companyName:
            opportunities.sort { $0.companyName < $1.companyName }
        case .productName:
            opportunities.sort { $0.productName < $1.productName }
        case .closeDate:
            opportunities.sort { $0.closeDate > $1.closeDate }  // Newest to Oldest
        }

        return opportunities
    }

    var body: some View {
        NavigationStack {
            VStack {
                // 🔍 Search Bar
                HStack {
                    TextField("Search Opportunities", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing)
                    .opacity(searchText.isEmpty ? 0 : 1)
                }
                .padding(.top)

                // 🔄 Sorting Picker
                Picker("Sort by", selection: $sortOption) {
                    ForEach(OpportunitySortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                // 📋 List of Opportunities
                List(filteredOpportunities, id: \.id) { opportunity in
                    OpportunityRowView(
                        opportunity: opportunity,
                        currentMethodology: currentMethodology,
                        viewModel: viewModel,
                        selectedBANTItem: $selectedBANTItem,
                        selectedQualificationItem: $selectedQualificationItem,
                        editingOpportunity: $editingOpportunity,
                        isPresentingEditOpportunity: $isPresentingEditOpportunity,
                        isPresentingAIGuidance: $isPresentingAIGuidance,
                        setAIGuidanceText: { aiGuidanceText = $0 }
                    )
                }
            }
            .navigationTitle("Opportunities")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresentingHelp = true }) {
                        Image(systemName: "questionmark.circle")
                            .font(.title)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresentingAddOpportunity = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                }
            }
            .onAppear { viewModel.fetchOpportunities() }
            .sheet(item: $selectedBANTItem) { item in
                if currentMethodology == "BANT" {
                    BANTEditorView(viewModel: viewModel, opportunity: item.opportunity, bantType: item.bantType)
                }
            }
            .sheet(item: $selectedQualificationItem) { item in
                if currentMethodology == "MEDDIC" {
                    MEDDICEditorView(viewModel: viewModel, opportunity: item.opportunity, metricType: item.qualificationType)
                } else if currentMethodology == "SCUBATANK" {
                    SCUBATANKEditorView(viewModel: viewModel, opportunity: item.opportunity, elementType: item.qualificationType)
                }
            }
            .onChange(of: selectedQualificationItem) {
                if selectedQualificationItem == nil {
                    viewModel.fetchOpportunities()
                }
            }
            .sheet(isPresented: $isPresentingAddOpportunity) {
                AddOpportunityView(viewModel: viewModel)
            }
            .sheet(item: $editingOpportunity) { opportunity in
                EditOpportunityView(viewModel: viewModel, opportunity: opportunity)
            }
            .sheet(isPresented: $isPresentingAIGuidance) {
                AIGuidancePlaceholderView(aiText: aiGuidanceText)
            }
            .sheet(isPresented: $isPresentingHelp) {
                OpportunityHelpView()
            }
        }
    }
}

struct AIGuidancePlaceholderView: View {
    var aiText: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                ScrollView {
                    if aiText.isEmpty || aiText == "Generating AI Guidance..." {
                        ProgressView("Generating AI Guidance...")
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(aiText)
                            .padding()
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer()
            }
            .navigationTitle("AI Guidance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: aiText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .padding()
        }
    }
}

// Helper view for displaying qualification icon depending on methodology
struct QualificationIconView: View {
    let opportunity: OpportunityWrapper
    let currentMethodology: String
    let onSelect: (SelectedQualificationItem?) -> Void
    let onSelectBANT: (SelectedBANTItem?) -> Void

    var body: some View {
        Group {
            if currentMethodology == "BANT" {
                BANTIndicatorView(opportunity: opportunity) { bantType in
                    onSelectBANT(SelectedBANTItem(opportunity: opportunity, bantType: bantType))
                }
            } else if currentMethodology == "MEDDIC" {
                MEDDICIndicatorView(opportunity: opportunity) { meddicType in
                    onSelect(SelectedQualificationItem(opportunity: opportunity, qualificationType: meddicType.rawValue))
                }
            } else if currentMethodology == "SCUBATANK" {
                SCUBATANKIndicatorView(opportunity: opportunity) { scubatankType in
                    onSelect(SelectedQualificationItem(opportunity: opportunity, qualificationType: scubatankType.rawValue))
                }
            }
        }
    }
}

struct OpportunityRowView: View {
    let opportunity: OpportunityWrapper
    let currentMethodology: String
    @ObservedObject var viewModel: OpportunityViewModel
    @Binding var selectedBANTItem: SelectedBANTItem?
    @Binding var selectedQualificationItem: SelectedQualificationItem?
    @Binding var editingOpportunity: OpportunityWrapper?
    @Binding var isPresentingEditOpportunity: Bool
    @Binding var isPresentingAIGuidance: Bool
    let setAIGuidanceText: (String) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Button(action: {
                    editingOpportunity = opportunity
                    isPresentingEditOpportunity = true
                }) {
                    Text("Opportunity: \(opportunity.name)")
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                OpportunitySummaryView(opportunity: opportunity)
            }

            Spacer()

            QualificationIconView(
                opportunity: opportunity,
                currentMethodology: currentMethodology,
                onSelect: { selectedQualificationItem = $0 },
                onSelectBANT: { selectedBANTItem = $0 }
            )
        }
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.6)
                .onEnded { _ in
                    setAIGuidanceText("Generating AI Guidance...")
                    isPresentingAIGuidance = true
                    AIRecommendationManager.generateOpportunityGuidance(for: opportunity) { result in
                        setAIGuidanceText(result)
                    }
                }
        )
    }
}

struct OpportunityHelpView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Help Information")
            Text("Use the search bar to filter opportunities.")
            Text("Sort opportunities using the segmented control.")
            Text("Tap an opportunity to edit its details.")
            Text("Long press on an opportunity for AI guidance.")
            
            Text("Qualification Edit:")
                .font(.headline)
                .padding(.top)

            Text("Please select each icon relating to your chosen methodology and update its status with comments")

            Text("Red = unqualified")
            Text("Yellow = partially qualified")
            Text("Green = Qualified")
        }
        .padding()
    }
}
