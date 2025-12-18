//
//  SCOTSMANEditorView.swift
//  SalesDiver
//
//  Created by Ian Miller on 5/10/25.
//

import SwiftUI

struct SCOTSMANEditorView: View {
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
            return "Do you know who you are up against, and what their strengths are in this deal?"
        case "Originality":
            return "What is truly distinctive about your approach or offering for this customer?"
        case "Timescale":
            return "When does the client need the solution implemented by, and what is driving that timeline?"
        case "Size":
            return "Do you understand the scope/size of the opportunity (users, sites, devices, or effort) well enough to estimate accurately?"
        case "Money":
            return "Is there a realistic budget range identified, and does it align with the likely cost/value of the solution?"
        case "Authority":
            return "Have you identified and engaged the person(s) who can approve the purchase and drive the decision?"
        case "Need":
            return "Do you know the specific problems or challenges the prospect is facing that your solution can address?"
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
            .navigationTitle("\(elementType) SCOTSMAN")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // print("Saving SCOTSMAN - Element: \(elementType), Status: \(selectedStatus), Commentary: \(commentary)")
                        viewModel.updateSCOTSMANStatus(for: opportunity, elementType: elementType, status: selectedStatus, commentary: commentary)
                        dismiss()
                    }
                }
            }
            .onAppear {
                let statusInfo = viewModel.getSCOTSMANStatus(for: opportunity, elementType: elementType)
                // print("Loaded SCOTSMAN - Element: \(elementType), Status (Type: \(type(of: statusInfo.status))) = \(statusInfo.status), Commentary: \(statusInfo.commentary)")
                selectedStatus = Int("\(statusInfo.status)") ?? 0
                commentary = statusInfo.commentary
            }
        }
    }
}
