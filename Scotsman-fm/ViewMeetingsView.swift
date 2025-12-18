import SwiftUI
import CoreData

struct ViewMeetingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var meetings: [MeetingsEntity] = []
    @State private var selectedMeeting: MeetingsEntity? = nil  // New state to track selected meeting
    @State private var isEditSheetPresented = false
    @State private var refreshID = UUID()  // New state for refresh ID
    @State private var isAddMeetingPresented = false
    @State private var navigateToAddMeeting = false
    @State private var searchText: String = ""

    private func fetchMeetings() {
        let request: NSFetchRequest<MeetingsEntity> = MeetingsEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MeetingsEntity.date, ascending: false)]

        do {
            meetings = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch meetings: \(error.localizedDescription)")
        }
    }

    private func deleteMeeting(at offsets: IndexSet) {
        offsets.forEach { index in
            let meetingToDelete = meetings[index]
            viewContext.delete(meetingToDelete)
            meetings.remove(at: index)
        }

        do {
            try viewContext.save()
        } catch {
            print("Failed to delete meeting: \(error.localizedDescription)")
        }
    }

    var body:  some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(meetings.filter { meeting in
                        searchText.isEmpty ||
                        (meeting.company?.name?.localizedCaseInsensitiveContains(searchText) == true) ||
                        (meeting.opportunity?.name?.localizedCaseInsensitiveContains(searchText) == true) ||
                        (meeting.date != nil && dateFormatter.string(from: meeting.date!).localizedCaseInsensitiveContains(searchText))
                    }, id: \.objectID) { meeting in
                        ZStack {
                            HStack(alignment: .top) {
                                MeetingRowView(meeting: meeting)

                                if let opportunity = meeting.opportunity {
                                    OpportunityDetailsView(opportunity: opportunity)
                                        .padding(.leading, 16) // Optional visual spacing
                                }
                            }
                            .background(selectedMeeting == meeting ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                            .onTapGesture {
                                selectedMeeting = meeting
                            }
                        }
                    }
                    .onDelete(perform: deleteMeeting)
                }
                .id(refreshID)  // Add ID to refresh the List
                .onAppear {
                    fetchMeetings()
                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by company, opportunity, or date")
                .navigationTitle("View Meetings")
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button("Edit Meeting") {
                            isEditSheetPresented = true
                        }
                        .disabled(selectedMeeting == nil)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            navigateToAddMeeting = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                        }
                    }
                }
                .navigationDestination(isPresented: $navigateToAddMeeting) {
                    PlanMeetingView().environment(\.managedObjectContext, viewContext)
                }

                HStack(spacing: 16) {
                    if let meetingToStart = selectedMeeting {
                        NavigationLink(destination: RecordMeetingView(meeting: meetingToStart)) {
                            Text("Record Meeting")
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }

                        NavigationLink(destination: MeetingSummaryView(meeting: meetingToStart)) {
                            Text("Review Meeting Summary")
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }

                        Button(action: {
                            if let index = meetings.firstIndex(of: meetingToStart) {
                                deleteMeeting(at: IndexSet(integer: index))
                                selectedMeeting = nil
                            }
                        }) {
                            Text("Delete Meeting")
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    } else {
                        ForEach(["Record Meeting", "Review Meeting Summary", "Delete Meeting"], id: \.self) { title in
                            Text(title)
                                .foregroundColor(.gray)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.bottom)
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $isEditSheetPresented, onDismiss: {
            fetchMeetings()
        }) {
            if let meeting = selectedMeeting {
                EditMeetingSheet(meeting: meeting, isPresented: $isEditSheetPresented)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .onChange(of: isEditSheetPresented) {
            if !isEditSheetPresented {
                fetchMeetings()
                if let id = selectedMeeting?.objectID {
                    selectedMeeting = try? viewContext.existingObject(with: id) as? MeetingsEntity
                }
                refreshID = UUID()  // Update refresh ID
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

private let shortDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

struct MeetingRowView: View {
    let meeting: MeetingsEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meeting.title ?? "Untitled Meeting")
                .font(.headline)

            if let date = meeting.date {
                Text("Date: \(date, formatter: dateFormatter)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            if let company = meeting.company {
                Text("Company: \(company.name ?? "Unknown Company")")
                    .font(.subheadline)
            }

            if let contacts = meeting.contacts as? Set<ContactsEntity>, !contacts.isEmpty {
                let attendeeNames = contacts.map { "\($0.firstName ?? "") \($0.lastName ?? "")" }.joined(separator: ", ")
                Text("Attendees: \(attendeeNames)")
                    .font(.subheadline)
            }

            if let objective = meeting.objective {
                Text("Objective: \(objective)")
                    .font(.subheadline)
                    .italic()
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OpportunityDetailsView: View {
    let opportunity: OpportunityEntity

    @AppStorage("selectedMethodology") private var currentMethodology: String = "BANT"

    private var wrapper: OpportunityWrapper {
        OpportunityWrapper(managedObject: opportunity)
    }

    @ViewBuilder
    private var indicatorView: some View {
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

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Opportunity: \(opportunity.name ?? "Unknown")")
                .font(.subheadline)
                .foregroundColor(.blue)

            Text("Estimated Value: $\(opportunity.estimatedValue, specifier: "%.2f")")
                .font(.subheadline)
                .foregroundColor(.gray)

            if let closeDate = opportunity.closeDate {
                Text("Expected Close: \(closeDate, formatter: shortDateFormatter)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            indicatorView
                .scaleEffect(0.7)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
