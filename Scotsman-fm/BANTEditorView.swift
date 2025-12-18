//
//  BANTEditorView.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//

import SwiftUI

struct BANTEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: OpportunityViewModel
    @ObservedObject var opportunity: OpportunityWrapper  // ✅ FIX: Use global `OpportunityWrapper`
    var bantType: BANTIndicatorView.BANTType

    @State private var selectedStatus: Int = 0
    @State private var commentary: String = ""

    init(viewModel: OpportunityViewModel, opportunity: OpportunityWrapper, bantType: BANTIndicatorView.BANTType) {
        self.viewModel = viewModel
        self.opportunity = opportunity
        self.bantType = bantType
        switch bantType {
        case .budget:
            _selectedStatus = State(initialValue: opportunity.budgetStatus)
            _commentary = State(initialValue: opportunity.budgetCommentary)
        case .authority:
            _selectedStatus = State(initialValue: opportunity.authorityStatus)
            _commentary = State(initialValue: opportunity.authorityCommentary)
        case .need:
            _selectedStatus = State(initialValue: opportunity.needStatus)
            _commentary = State(initialValue: opportunity.needCommentary)
        case .timing:
            _selectedStatus = State(initialValue: opportunity.timingStatus)
            _commentary = State(initialValue: opportunity.timingCommentary)
        }
    }

    var title: String {
        switch bantType {
        case .budget: return "Budget Qualification"
        case .authority: return "Authority Qualification"
        case .need: return "Need Qualification"
        case .timing: return "Timing Qualification"
        }
    }

    var keyQuestion: String {
        switch bantType {
        case .budget:
            return "Is the client’s budget adequate to meet their needs?"
        case .authority:
            return "Have you met the individual with the budget authority and the power to make the final purchase decision?"
        case .need:
            return "Do you know the specific problems or challenges the prospect is facing that your solution can address?"
        case .timing:
            return "When does the client need the solution implemented by?"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Select Qualification Status")) {
                    Picker("Status", selection: $selectedStatus) {
                        Text("Not Qualified").tag(0)
                        Text("In Process").tag(1)
                        Text("Qualified").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Commentary")) {
                    TextEditor(text: $commentary)
                        .frame(height: 100)
                        .border(Color.gray, width: 1)
                }

                Section(header: Text("Key Question")) {
                    Text(keyQuestion)
                        .italic()
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveQualification()
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveQualification() {
        // print("Debug: Saving qualification for bantType: \(bantType)")
        // print("Debug: Selected status: \(selectedStatus)")
        // print("Debug: Commentary: \(commentary)")
        
        switch bantType {
        case .budget:
            break
        case .authority:
            break
        case .need:
            break
        case .timing:
            break
        }
        
        viewModel.updateBANT(opportunity: opportunity, bantType: bantType, status: selectedStatus, commentary: commentary)
    }
}
