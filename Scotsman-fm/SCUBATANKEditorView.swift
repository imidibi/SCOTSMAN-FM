//
//  SCUBATANKEditorView.swift
//  SalesDiver
//
//  Created by Ian Miller on 5/10/25.
//

import SwiftUI

struct SCUBATANKEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: OpportunityViewModel
    var opportunity: OpportunityWrapper
    var elementType: String

    @State private var selectedStatus: Int = 0
    @State private var commentary: String = ""

    var keyQuestion: String {
        switch elementType {
        case "Solution":
            return "Has the customer confirmed that the solution you are proposing will do the job?"
        case "Competition":
            return "Do you know who you are up against? Do they have any secret sauce?"
        case "Uniques":
            return "Have you identified the elements in your solution that make you stand out against the competition?"
        case "Benefits":
            return "Have you clearly articulated the tangible benefits the client will gain from your proposal?"
        case "Authority":
            return "Have you met the individual with the budget authority and the power to make the final purchase decision?"
        case "Timescale":
            return "When does the client need the solution implemented by?"
        case "Action Plan":
            return "Have you scheduled multiple touch points with the client like reference calls, executive dinner etc.?"
        case "Need":
            return "Do you know the specific problems or challenges the prospect is facing that your solution can address?"
        case "Kash":
            return "Is the client’s budget adequate to meet their needs?"
        default:
            return ""
        }
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
                    .id(selectedStatus)  // Forces view refresh when status updates
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
            .navigationTitle("\(elementType) Qualification")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // print("Saving SCUBATANK - Element: \(elementType), Status: \(selectedStatus), Commentary: \(commentary)")
                        viewModel.updateSCUBATANKStatus(for: opportunity, elementType: elementType, status: selectedStatus, commentary: commentary)
                        dismiss()
                    }
                }
            }
            .onAppear {
                let statusInfo = viewModel.getSCUBATANKStatus(for: opportunity, elementType: elementType)
                // print("Loaded SCUBATANK - Element: \(elementType), Status (Type: \(type(of: statusInfo.status))) = \(statusInfo.status), Commentary: \(statusInfo.commentary)")
                selectedStatus = Int("\(statusInfo.status)") ?? 0
                commentary = statusInfo.commentary
            }
        }
    }
}
