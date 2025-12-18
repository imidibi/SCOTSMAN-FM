//
//  MeetingSummaryView.swift
//  SalesDiver
//
//  Created by Ian Miller on 5/19/25.
//
import SwiftUI
import CoreData



struct MeetingSummaryView: View {
    @ObservedObject var meeting: MeetingsEntity

    @AppStorage("selectedMethodology") private var currentMethodology: String = "BANT"
    @State private var selectedBANTItem: SelectedBANTItem? = nil
    @State private var selectedMEDDICItem: SelectedQualificationItem? = nil
    @State private var selectedSCUBATANKItem: SelectedSCUBATANKItem? = nil
    @StateObject private var viewModel = OpportunityViewModel()
    @State private var selectedOpportunity: OpportunityWrapper?
    @State private var aiRecommendation: String = ""

    var body: some View {
        let resolvedDate = meeting.date ?? Date()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Header Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title ?? "Untitled Meeting")
                        .font(.title2)
                        .bold()
                    Text(resolvedDate, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let company = meeting.company?.name {
                        Text("Company: \(company)")
                    }
                    if let opportunity = meeting.opportunity?.name {
                        Text("Opportunity: \(opportunity)")
                    }
                    if let objective = meeting.objective {
                        Text("Objective: \(objective)")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                Divider()

                // Attendees
                if let attendees = meeting.contacts as? Set<ContactsEntity>, !attendees.isEmpty {
                    let sortedAttendees = attendees.sorted(by: {
                        let nameA = "\($0.firstName ?? "") \($0.lastName ?? "")"
                        let nameB = "\($1.firstName ?? "") \($1.lastName ?? "")"
                        return nameA < nameB
                    })
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Attendees:")
                            .font(.headline)
                        ForEach(sortedAttendees, id: \.self) { contact in
                            Text("\(contact.firstName ?? "") \(contact.lastName ?? "")")
                        }
                    }
                    Divider()
                }

                // Questions & Notes
                if let questions = meeting.questions as? Set<MeetingQuestionEntity>, !questions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Questions & Notes:")
                            .font(.headline)
                        let sortedQuestions = questions.sorted(by: { ($0.questionText ?? "") < ($1.questionText ?? "") })
                        ForEach(sortedQuestions, id: \.self) { question in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(question.questionText ?? "")
                                    .font(.subheadline)
                                    .bold()
                                Text(question.answer ?? "No notes captured.")
                                    .foregroundColor(.secondary)
                                if let answer = question.answer, answer.contains("[INSIGHT]") {
                                    Text("⭐ Key Insight Identified")
                                        .foregroundColor(.yellow)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    Divider()
                }

                // Transcription
                if let transcript = meeting.notes, !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Full Transcription:")
                            .font(.headline)
                        Text(transcript)
                            .foregroundColor(.secondary)
                    }
                    Divider()
                }

                // Qualification Status Section with interactive icons
                VStack(alignment: .leading, spacing: 4) {
                    Text("Qualification Summary:")
                        .font(.headline)
                    Text("Please edit the qualification status based on the meeting outcome:")
                        .foregroundColor(.secondary)
                    if let opportunity = meeting.opportunity {
                        let wrapper = OpportunityWrapper(managedObject: opportunity)
                        switch currentMethodology {
                        case "BANT":
                            BANTIndicatorView(opportunity: wrapper, onBANTSelected: { selected in
                                selectedBANTItem = SelectedBANTItem(opportunity: wrapper, bantType: selected)
                            })
                        case "MEDDIC":
                            MEDDICIndicatorView(opportunity: wrapper, onMEDDICSelected: { selected in
                                selectedMEDDICItem = SelectedQualificationItem(opportunity: wrapper, qualificationType: selected.rawValue)
                            })
                        case "SCUBATANK":
                            SCUBATANKIndicatorView(opportunity: wrapper, onSCUBATANKSelected: { selected in
                                selectedSCUBATANKItem = SelectedSCUBATANKItem(opportunity: wrapper, scubatankType: selected)
                            })
                        default:
                            EmptyView()
                        }
                    }
                }

                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Recommendation:")
                        .font(.headline)
                    Text(aiRecommendation)
                        .foregroundColor(.primary)
                        .padding(.top, 2)
                    Button("Generate Recommendation") {
                        generateAIRecommendation()
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            if aiRecommendation.isEmpty,
               let saved = meeting.aiRecommendation,
               !saved.isEmpty {
                aiRecommendation = saved
            }
        }
        .navigationTitle("Meeting Summary")
        .sheet(item: $selectedBANTItem) { (item: SelectedBANTItem) in
            BANTEditorView(viewModel: viewModel, opportunity: item.opportunity, bantType: item.bantType)
        }
        .sheet(item: $selectedMEDDICItem) { (item: SelectedQualificationItem) in
            MEDDICEditorView(viewModel: viewModel, opportunity: item.opportunity, metricType: item.qualificationType)
        }
        .sheet(item: $selectedSCUBATANKItem) { (item: SelectedSCUBATANKItem) in
            SCUBATANKEditorView(viewModel: viewModel, opportunity: item.opportunity, elementType: item.scubatankType.rawValue)
        }
    }
    private func generateAIRecommendation() {
        aiRecommendation = "Generating recommendation..."
        AIRecommendationManager.generateSalesRecommendation(for: meeting, methodology: currentMethodology) { result in
            aiRecommendation = result
            meeting.aiRecommendation = result
            try? meeting.managedObjectContext?.save()
        }
    }
}

struct QualificationEditorRouter: View {
    let editorType: String
    let wrapper: OpportunityWrapper?
    let bantType: BANTIndicatorView.BANTType?
    let meddicType: MEDDICType?
    let scubatankType: SCUBATANKType?
    let viewModel: OpportunityViewModel

    var body: some View {
        if let wrapper = wrapper {
            switch editorType {
            case "BANT":
                if let type = bantType {
                    BANTEditorView(viewModel: viewModel, opportunity: wrapper, bantType: type)
                } else {
                    Text("Missing BANT type")
                }
            case "MEDDIC":
                if let type = meddicType {
                    MEDDICEditorView(viewModel: viewModel, opportunity: wrapper, metricType: type.rawValue)
                } else {
                    Text("Missing MEDDIC type")
                }
            case "SCUBATANK":
                if let type = scubatankType {
                    SCUBATANKEditorView(viewModel: viewModel, opportunity: wrapper, elementType: type.rawValue)
                } else {
                    Text("Missing SCUBATANK type")
                }
            default:
                Text("Unknown qualification method")
            }
        } else {
            ProgressView("Loading...")
        }
    }
}



// If not available globally, define SelectedSCUBATANKItem here:
struct SelectedSCUBATANKItem: Identifiable {
    let id = UUID()
    let opportunity: OpportunityWrapper
    let scubatankType: SCUBATANKType
}
