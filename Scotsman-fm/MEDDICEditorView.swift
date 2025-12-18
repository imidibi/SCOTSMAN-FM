//
//  MEDDICEditorView.swift
//  SalesDiver
//
//  Created by Ian Miller on 5/10/25.
//

import SwiftUI

struct MEDDICEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: OpportunityViewModel
    var opportunity: OpportunityWrapper
    var metricType: String

    @State private var selectedStatus: Int
    @State private var commentary: String

    init(viewModel: OpportunityViewModel, opportunity: OpportunityWrapper, metricType: String) {
        self.viewModel = viewModel
        self.opportunity = opportunity
        self.metricType = metricType

        let statusInfo = viewModel.getMEDDICStatus(for: opportunity, metricType: metricType)
        _selectedStatus = State(initialValue: statusInfo.status)
        _commentary = State(initialValue: statusInfo.commentary)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Select Qualification Status")) {
                    Picker("Status", selection: $selectedStatus) {
                        Text("Not Qualified").tag(0)
                        Text("In Progress").tag(1)
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
            .navigationTitle("\(metricType) Qualification")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.updateMEDDICStatus(for: opportunity, metricType: metricType, status: selectedStatus, commentary: commentary)
                        dismiss()
                    }
                }
            }
        }
    }

    var keyQuestion: String {
        switch metricType {
        case "Metrics":
            return "What are the quantifiable results and business objectives that the prospect is trying to achieve?"
        case "Economic Buyer":
            return "Have you met the individual with the budget authority and the power to make the final purchase decision?"
        case "Decision Criteria":
            return "Do you know the specific requirements, standards, and guidelines the prospect will use to evaluate your proposal?"
        case "Decision Process":
            return "Do you know the series of steps and stakeholders involved in the buying decision?"
        case "Identify Pain":
            return "Do you know the specific problems or challenges the prospect is facing that your solution can address?"
        case "Champion":
            return "Have you created an internal advocate within the prospect's organization who can support your solution and help navigate the sales process?"
        default:
            return ""
        }
    }
}
