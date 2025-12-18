//
//  EditMeetingView.swift
//  SalesDiver
//
//  Created by Ian Miller on 4/8/25.
//
import Foundation
import CoreData
import SwiftUI

struct EditMeetingView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: EditMeetingViewModel
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Meeting Details")) {
                    HStack {
                        Text("Title")
                        TextField("Enter meeting title", text: $viewModel.title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    HStack {
                        Text("Date")
                        DatePicker("", selection: $viewModel.date, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                    HStack {
                        Text("Objective")
                        TextField("Enter meeting objective", text: $viewModel.objective)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Section(header: Text("Attendees")) {
                    HStack(alignment: .top) {
                        Text("Attendee List")
                        Text(viewModel.selectedAttendees.map {
                            [ $0.firstName, $0.lastName ]
                                .compactMap { $0 }
                                .joined(separator: " ")
                        }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    }
                }
                
                Section(header: Text("Questions")) {
                    List {
                        ForEach(viewModel.questions, id: \.self) { question in
                            Text(question.questionText ?? "Untitled")
                        }
                        .onDelete(perform: deleteQuestions)
                    }
                }
            }
            .navigationBarTitle("Edit Meeting", displayMode: .inline)
            .navigationBarItems(trailing: Button("Save") {
                viewModel.saveChanges()
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func deleteQuestions(at offsets: IndexSet) {
        offsets.map { viewModel.questions[$0] }.forEach(viewModel.removeQuestion)
    }
}
