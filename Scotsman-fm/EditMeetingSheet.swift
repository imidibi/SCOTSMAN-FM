import SwiftUI
import CoreData

struct EditMeetingSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool
    @StateObject private var viewModel: EditMeetingViewModel

    init(meeting: MeetingsEntity, isPresented: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: EditMeetingViewModel(meeting: meeting, context: meeting.managedObjectContext!))
        _isPresented = isPresented
    }

    var body: some View {
        mainView
    }

    private var meetingDetailsSection: some View {
        Section(header: Text("Meeting Details"), content: {
            HStack {
                Text("Title:")
                    .frame(width: 100, alignment: .leading)
                TextField("Enter meeting title", text: $viewModel.title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            HStack {
                Text("Date:")
                    .frame(width: 100, alignment: .leading)
                DatePicker("", selection: $viewModel.date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            HStack {
                Text("Company:")
                    .frame(width: 100, alignment: .leading)
                Text(viewModel.companyName ?? "Not set")
                    .foregroundColor(.gray)
            }
            HStack {
                Text("Objective:")
                    .frame(width: 100, alignment: .leading)
                TextField("Enter meeting objective", text: $viewModel.objective)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        })
    }

    private var attendeesSection: some View {
        Section(header: Text("Attendees"), content: {
            if viewModel.availableContacts.isEmpty {
                Text("No contacts available")
                    .foregroundColor(.gray)
            } else {
                ForEach(viewModel.availableContacts.indices, id: \.self) { index in
                    let contact = viewModel.availableContacts[index]
                    HStack {
                        // Combine firstName and lastName for display.
                        Text("\(contact.firstName ?? "") \(contact.lastName ?? "")")
                        Spacer()
                        if viewModel.selectedAttendees.contains(where: { $0.objectID == contact.objectID }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.toggleSelection(for: contact)
                    }
                }
            }
        })
    }

    private var selectedQuestionsSection: some View {
        if viewModel.questions.isEmpty {
            return AnyView(
                Section(header: Text("Selected Questions")) {
                    Text("No questions selected")
                        .foregroundColor(.gray)
                }
            )
        } else {
            return AnyView(
                Section(header: Text("Selected Questions")) {
                    ForEach(viewModel.questions, id: \.objectID) { question in
                        HStack {
                            Text(question.questionText ?? "")
                                .foregroundColor(.primary)
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeQuestion(question)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(BorderlessButtonStyle()) // Prevents triggering actions on row
                        }
                        .contentShape(Rectangle()) // Ensures only button is tappable
                    }
                }
            )
        }
    }

    private var mainView: some View {
        NavigationView {
            Form {
                meetingDetailsSection
                attendeesSection
                selectedQuestionsSection
            }
            .navigationTitle("Edit Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveChanges()
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - EditMeetingViewModel
class EditMeetingViewModel: ObservableObject {
    let meeting: MeetingsEntity
    let context: NSManagedObjectContext
    var companyName: String? {
        meeting.company?.name
    }

    @Published var title: String
    @Published var date: Date
    @Published var objective: String
    @Published var questions: [MeetingQuestionEntity]
    @Published var selectedAttendees: [ContactsEntity] = []

    init(meeting: MeetingsEntity, context: NSManagedObjectContext) {
        self.meeting = meeting
        self.context = context
        self.title = meeting.title ?? ""
        self.date = meeting.date ?? Date()
        self.objective = meeting.objective ?? ""
        self.questions = (meeting.questions as? Set<MeetingQuestionEntity>)?.sorted { ($0.questionText ?? "") < ($1.questionText ?? "") } ?? []
        self.selectedAttendees = (meeting.contacts as? Set<ContactsEntity>)?.sorted { ($0.firstName ?? "") < ($1.firstName ?? "") } ?? []
    }

    func saveChanges() {
        objectWillChange.send()
        meeting.title = title
        meeting.date = date
        meeting.objective = objective
        meeting.contacts = NSSet(array: selectedAttendees)
        meeting.questions = NSSet(array: questions)

        do {
            try context.save()
        } catch {
            // print("Error saving meeting changes: \(error.localizedDescription)")
        }
    }

    func toggleSelection(for contact: ContactsEntity) {
        objectWillChange.send()
        if let index = selectedAttendees.firstIndex(of: contact) {
            selectedAttendees.remove(at: index)
        } else {
            selectedAttendees.append(contact)
        }
        meeting.contacts = NSSet(array: selectedAttendees)
    }

    func removeQuestion(_ question: MeetingQuestionEntity) {
        objectWillChange.send()
        if let index = questions.firstIndex(of: question) {
            questions.remove(at: index)
            meeting.questions = NSSet(array: questions)
        }
    }
}

extension EditMeetingViewModel {
    var availableContacts: [ContactsEntity] {
        if let companyContacts = meeting.company?.contacts as? Set<ContactsEntity> {
            return Array(companyContacts).sorted { ($0.firstName ?? "") < ($1.firstName ?? "") }
        }
        return []
    }
}
