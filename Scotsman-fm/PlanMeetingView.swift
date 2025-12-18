import SwiftUI
import CoreData


struct PlanMeetingView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode
    @State private var newMeeting: MeetingsEntity?
    @State private var meetingTitle: String = ""
    @State private var meetingDate: Date = Date()
    @State private var processedCategories: [String] = [] // Track categories already processed
    @FocusState private var isCompanySearchFocused: Bool
    private static func computeDefaultMeetingTime() -> Date {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
    }

    // Update the getRelevantQuestions(for:) function:
    private func getRelevantQuestions(for category: String) -> [BANTQuestion] {
        // Trim whitespace and lower-case the category for a robust comparison
        let normalizedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // print("DEBUG: Fetching questions for category '\(category)' (normalized: '\(normalizedCategory)')")

        let fetchedQuestions = allQuestions.filter { question in
            if let questionCategory = question.category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                let matches = questionCategory == normalizedCategory
//                print("DEBUG: Checking question '\(question.questionText ?? \"Unknown Question\")' - Category: \(questionCategory) - Matches: \(matches)")
                return matches
            } else {
//                print("DEBUG: Question has no category - \(question.questionText ?? \"Unknown Question\")")
                return false
            }
        }
        // print("DEBUG: Fetched \(fetchedQuestions.count) questions for category '\(category)'")
        return fetchedQuestions
    }

    @State private var meetingTime: Date = PlanMeetingView.computeDefaultMeetingTime()
    @State private var selectedCompany: CompanyEntity?
    @State private var selectedOpportunity: OpportunityEntity?
    @State private var selectedAttendees: Set<ContactsEntity> = []
    @State private var meetingObjective: String = ""
    @State private var companySearchText: String = ""
    @State private var opportunitySearchText: String = ""
    @State private var contactsSearchText: String = ""
    @State private var showingDatePicker = false
    @State private var showingTimePicker = false
    @State private var showCompanyPicker = false
    @State private var showOpportunityPicker = false
    @State private var showAttendeePicker = false
    
    @State private var showingQuestions = false
    @State private var displayedQuestions: [BANTQuestion] = []
    @State private var selectedQuestions: Set<BANTQuestion> = []
    @State private var currentCategoryIndex: Int = 0
    @State private var currentCategory: String? = nil
    @State private var showQuestionSelection: Bool = false
    @State private var objectiveDefined: Bool = false
    @State private var dialogueText: String = ""

    @FetchRequest(entity: CompanyEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \CompanyEntity.name, ascending: true)])
    private var companies: FetchedResults<CompanyEntity>
    
    @FetchRequest(entity: BANTQuestion.entity(), sortDescriptors: [])
    private var allQuestions: FetchedResults<BANTQuestion>

    init() {
        _meetingTitle = State(initialValue: "")
        _meetingDate = State(initialValue: Date())
        _meetingTime = State(initialValue: PlanMeetingView.computeDefaultMeetingTime())
        _selectedCompany = State(initialValue: nil)
        _selectedOpportunity = State(initialValue: nil)
        _selectedAttendees = State(initialValue: [])
        _meetingObjective = State(initialValue: "")
    }
    
    var filteredOpportunities: [OpportunityEntity] {
        guard let company = selectedCompany else { return [] }
        guard let opportunities = company.opportunities as? Set<OpportunityEntity> else { return [] }
        let sorted = opportunities.sorted {
            let name1 = $0.name ?? ""
            let name2 = $1.name ?? ""
            return name1 < name2
        }
        return sorted
    }

    private func toggleQuestionSelection(_ question: BANTQuestion) {
        if selectedQuestions.contains(question) {
            selectedQuestions.remove(question)
        } else {
            selectedQuestions.insert(question)
        }
    }
    
    private func getWorstQualifiedCategory() -> String? {
        guard let opportunity = selectedOpportunity else { return nil }
        
        let categories = [
            ("Budget", opportunity.budgetStatus),
            ("Authority", opportunity.authorityStatus),
            ("Need", opportunity.needStatus),
            ("Timescale", opportunity.timingStatus)
        ]
        
        let sortedCategories = categories.sorted { (first, second) -> Bool in
            return statusValue(first.1) > statusValue(second.1)
        }
        
        return sortedCategories.first?.0
    }
    
    private func statusValue(_ status: Int16) -> Int {
        switch status {
        case 0: return 3  // Red
        case 1: return 2  // Yellow
        case 2: return 1  // Green
        default: return 0
        }
    }


    func completeObjective() {
        objectiveDefined = true
        proceedToNextCategory()
    }

    private func fetchQuestions(for category: String) -> [BANTQuestion] {
        return allQuestions.filter { question in
            question.category == category
        }
    }
    
    var visibleOpportunities: [OpportunityEntity] {
        var result: [OpportunityEntity] = []
        for opportunity in filteredOpportunities {
            let name = opportunity.name ?? ""
            if opportunitySearchText.isEmpty || name.localizedCaseInsensitiveContains(opportunitySearchText) {
                result.append(opportunity)
            }
        }
        return result
    }
    
    var filteredContacts: [ContactsEntity] {
        guard let company = selectedCompany else { return [] }
        guard let contacts = company.contacts as? Set<ContactsEntity> else { return [] }
        let sorted = contacts.sorted {
            let name1 = $0.firstName ?? ""
            let name2 = $1.firstName ?? ""
            return name1 < name2
        }
        return sorted
    }
    
    var visibleContacts: [ContactsEntity] {
        guard let company = selectedCompany else { return [] }
        guard let contacts = company.contacts as? Set<ContactsEntity> else { return [] }
        
        let sortedContacts = contacts.sorted {
            let name1 = "\($0.firstName ?? "") \($0.lastName ?? "")"
            let name2 = "\($1.firstName ?? "") \($1.lastName ?? "")"
            return name1 < name2
        }
        
        if contactsSearchText.isEmpty {
            return sortedContacts
        } else {
            return sortedContacts.filter { contact in
                let fullName = "\((contact.firstName ?? "")) \((contact.lastName ?? ""))"
                return fullName.localizedCaseInsensitiveContains(contactsSearchText)
            }
        }
    }
    
    private func saveSelectedQuestion(question: BANTQuestion, meeting: MeetingsEntity, answer: String = "") {
        let context = viewContext
 
        // Check if the question is already associated with the meeting
        if meeting.questions?.contains(where: { ($0 as? MeetingQuestionEntity)?.questionID == question.id }) == true {
            // print("Question already exists for this meeting.")
            return
        }
 
        // Create a new MeetingQuestionEntity
        let newMeetingQuestion = MeetingQuestionEntity(context: context)
        newMeetingQuestion.id = UUID()
        newMeetingQuestion.questionText = question.questionText ?? "Untitled Question"
        newMeetingQuestion.answer = answer
        newMeetingQuestion.category = question.category ?? "Unknown"
        newMeetingQuestion.questionID = question.id ?? UUID() // Assuming BANTQuestion has a UUID `id`
        newMeetingQuestion.meeting = meeting
 
        // Save the context
        do {
            try context.save()
            // print("Question successfully saved to the meeting.")
        } catch {
            // print("Failed to save question: \(error.localizedDescription)")
        }
    }

    // MARK: - BANT Dialogue Functions

    private func generateBANTDialogue() {
        // Reset state for a new dialogue cycle.
        currentCategoryIndex = 0
        processedCategories.removeAll()
        
        // Create a meeting if one hasn't been created already.
        if newMeeting == nil {
            let meeting = MeetingsEntity(context: viewContext)
            meeting.id = UUID()
            meeting.title = meetingTitle
            meeting.date = meetingDate
            meeting.objective = meetingObjective
            meeting.company = selectedCompany
            meeting.opportunity = selectedOpportunity
            meeting.contacts = NSSet(set: selectedAttendees)
            
            newMeeting = meeting
        }
        
        // Load questions for the first category.
        loadQuestionsForCurrentCategory()
    }
    
    private func loadQuestionsForCurrentCategory() {
        let categories: [String]
        switch currentMethodology {
        case "MEDDIC":
            categories = ["Metrics", "Economic Buyer", "Decision Criteria", "Decision Process", "Identify Pain", "Champion"]
        case "SCUBATANK":
            categories = ["Solution", "Competition", "Uniques", "Benefits", "Authority", "Timescale", "Action Plan", "Need", "Kash"]
        default:
            categories = ["Budget", "Authority", "Need", "Timescale"]
        }
        // If we've processed all categories, finish the cycle.
        guard currentCategoryIndex < categories.count else {
            showQuestionSelection = false
            dialogueText = "All categories have been processed."
//            print("DEBUG: AI Dialogue process complete.")
            return
        }
        
        let category = categories[currentCategoryIndex]
        currentCategory = category
        dialogueText = "Here are some \(category) questions to help you qualify the \(category) category."
        
        // Fetch questions from Core Data for this category.
        displayedQuestions = getRelevantQuestions(for: category)
        
        // If there are no questions for this category, skip to the next one.
        if displayedQuestions.isEmpty {
//            print("DEBUG: No questions available for \(category), skipping...")
            processedCategories.append(category)
            currentCategoryIndex += 1
            loadQuestionsForCurrentCategory()
        } else {
            showQuestionSelection = true
//            print("DEBUG: Presenting questions for category: \(category)")
        }
    }
    
    private func proceedToNextCategory() {
        // Save selected questions to the meeting.
        guard let meeting = newMeeting else {
            return
        }
        
        for question in selectedQuestions {
            saveSelectedQuestion(question: question, meeting: meeting)
//            print("DEBUG: Saved question: \(question.questionText ?? \"Unknown\")")
        }
        // Clear the current selection.
        selectedQuestions.removeAll()
        
        // Mark the current category as processed.
        if let category = currentCategory, !processedCategories.contains(category) {
            processedCategories.append(category)
        }
        
        // Move on to the next category.
        currentCategoryIndex += 1
        loadQuestionsForCurrentCategory()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    meetingHeaderSection
                    companyAndOpportunitySection
                    if selectedCompany != nil {
                        attendeesAndObjectiveSection
                    }
                    
                    // In the UI block that displays the questions, update it to use displayedQuestions
                    if showQuestionSelection, let currentCategory = currentCategory {
                        let relevantQuestions = displayedQuestions
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Let's discuss \(currentCategory)")
                                .font(.headline)
                            
                            ForEach(relevantQuestions, id: \.self) { question in
                                Button(action: { toggleQuestionSelection(question) }) {
                                    HStack {
                                        Text("• \(question.questionText ?? "Unknown Question")")
                                            .padding(.leading, 10)
                                        Spacer()
                                        if selectedQuestions.contains(question) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                            
                            Button("Save and Continue") {
                                proceedToNextCategory()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                    }
                    
                    if showingQuestions {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Select Questions for Qualification")
                                .font(.headline)
                            
                            List(displayedQuestions, id: \.self, selection: $selectedQuestions) { question in
                                Text(question.questionText ?? "No question text available")
                            }
                            .environment(\.editMode, .constant(.active))
                        }
                    }
                    
                }
                .padding()
            }
            .navigationTitle("Plan Meeting")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMeeting()
                    }
                }
            }
            .sheet(isPresented: $showCompanyPicker) {
                NavigationStack {
                    List {
                        Section {
                            TextField("Search Companies", text: $companySearchText)
                                .textFieldStyle(.roundedBorder)
                        }

                        ForEach(companies.filter {
                            companySearchText.isEmpty || ($0.name?.localizedCaseInsensitiveContains(companySearchText) ?? false)
                        }, id: \.self) { company in
                            Button(action: {
                                selectedCompany = company
                                companySearchText = ""
                                showCompanyPicker = false
                            }) {
                                Text(company.name ?? "Unknown")
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .navigationTitle("Select Company")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showCompanyPicker = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showOpportunityPicker) {
                NavigationStack {
                    List {
                        Section {
                            TextField("Search Opportunities", text: $opportunitySearchText)
                                .textFieldStyle(.roundedBorder)
                        }

                        ForEach(visibleOpportunities, id: \.self) { opportunity in
                            Button(action: {
                                selectedOpportunity = opportunity
                                opportunitySearchText = ""
                                showOpportunityPicker = false
                            }) {
                                Text(opportunity.name ?? "Untitled")
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .navigationTitle("Select Opportunity")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showOpportunityPicker = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var meetingHeaderSection: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading) {
                Text("Meeting Title")
                    .font(.headline)
                TextField("Enter Meeting Title", text: $meetingTitle)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .frame(width: 1)
                .foregroundColor(.black)
                .padding(.vertical)

            VStack(alignment: .leading, spacing: 10) {
                Text("Date & Time")
                    .font(.headline)

                Button(action: { showingDatePicker = true }) {
                    Text(meetingDate, style: .date)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .sheet(isPresented: $showingDatePicker) {
                    VStack {
                        DatePicker("Select Date", selection: $meetingDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                        Button("Done") {
                            showingDatePicker = false
                        }
                        .padding()
                    }
                }

                Button(action: { showingTimePicker = true }) {
                    Text(meetingTime, style: .time)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .sheet(isPresented: $showingTimePicker) {
                    VStack(spacing: 20) {
                        Text("Select Time")
                            .font(.headline)
                            .padding(.top)
                            .multilineTextAlignment(.center)

                        DatePicker("", selection: $meetingTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()

                        Button("Done") {
                            showingTimePicker = false
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
        }
    }

    private var companyAndOpportunitySection: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Company")
                    .font(.headline)
                Button(action: { showCompanyPicker = true }) {
                    HStack {
                        Text(selectedCompany?.name ?? "Select a Company")
                            .foregroundColor(selectedCompany == nil ? .gray : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .frame(width: 1)
                .foregroundColor(.black)
                .padding(.vertical)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Opportunity")
                        .font(.headline)
                    bantIcons
                }
                Button(action: { showOpportunityPicker = true }) {
                    HStack {
                        Text(selectedOpportunity?.name ?? "Select an Opportunity")
                            .foregroundColor(selectedOpportunity == nil ? .gray : .primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
        }
    }


    
    func saveMeeting() {
        // Use the existing newMeeting if available; otherwise, create a new meeting record.
        let meeting: MeetingsEntity
        if let existingMeeting = newMeeting {
            meeting = existingMeeting
        } else {
            meeting = MeetingsEntity(context: viewContext)
            meeting.id = UUID()
        }
        
        let calendar = Calendar.current
        let combinedDateTime = calendar.date(bySettingHour: calendar.component(.hour, from: meetingTime),
                                             minute: calendar.component(.minute, from: meetingTime),
                                             second: 0,
                                             of: meetingDate) ?? meetingDate
        
        meeting.title = meetingTitle
        meeting.date = combinedDateTime
        meeting.objective = meetingObjective
        meeting.company = selectedCompany
        meeting.opportunity = selectedOpportunity
        meeting.contacts = NSSet(set: selectedAttendees)
        
        do {
            try viewContext.save()
            // print("Meeting successfully saved!")
            
            // Clear the newMeeting state after saving to prevent future updates from modifying this record.
            newMeeting = nil
            
            presentationMode.wrappedValue.dismiss()
        } catch {
            // print("Failed to save meeting: \(error.localizedDescription)")
        }
    }
    
    struct MultipleSelectionRow: View {
        var title: String
        var isSelected: Bool
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    Text(title)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }

    
    @AppStorage("selectedMethodology") private var currentMethodology: String = "BANT"

    @ViewBuilder
    private var bantIcons: some View {
        if let opportunity = selectedOpportunity {
            let wrapper = OpportunityWrapper(managedObject: opportunity)
            if currentMethodology == "BANT" {
                BANTIndicatorView(opportunity: wrapper, onBANTSelected: { _ in })
            } else if currentMethodology == "MEDDIC" {
                MEDDICIndicatorView(opportunity: wrapper, onMEDDICSelected: { _ in })
            } else if currentMethodology == "SCUBATANK" {
                SCUBATANKIndicatorView(opportunity: wrapper, onSCUBATANKSelected: { _ in })
            } else {
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }
    
    private var attendeesAndObjectiveSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                
                // Attendees Selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Attendees")
                        .font(.headline)
                    Button(action: { showAttendeePicker = true }) {
                        HStack {
                            Text(selectedAttendees.isEmpty ? "Select Attendees" : selectedAttendees.map { "\($0.firstName ?? "") \($0.lastName ?? "")" }.joined(separator: ", "))
                                .foregroundColor(selectedAttendees.isEmpty ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                    }
                }
                .sheet(isPresented: $showAttendeePicker) {
                    NavigationStack {
                        List {
                            TextField("Search Attendees", text: $contactsSearchText)
                                .textFieldStyle(.roundedBorder)

                            ForEach(visibleContacts, id: \.self) { contact in
                                let fullName = "\(contact.firstName ?? "") \(contact.lastName ?? "")"
                                let isSelected = selectedAttendees.contains(contact)

                                MultipleSelectionRow(title: fullName, isSelected: isSelected) {
                                    selectedAttendees.formSymmetricDifference([contact])
                                }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                        .navigationTitle("Select Attendees")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showAttendeePicker = false
                                }
                            }
                        }
                    }
                }

                Rectangle()
                    .frame(width: 1)
                    .foregroundColor(Color.gray.opacity(0.4))
                    .padding(.vertical)

                // Meeting Objective and AI Dialogue Button
                VStack(alignment: .leading, spacing: 10) {
                    Text("Meeting Objective")
                        .font(.headline)
                    TextField("Enter Objective", text: $meetingObjective)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            completeObjective()
                        }

                    generateAIDialogueButton
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.4), lineWidth: 1))

            // Display AI Generated Dialogue
            if !dialogueText.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Questions Dialogue")
                        .font(.headline)

                    ScrollView {
                        Text(dialogueText)
                            .padding()
                    }
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                }
                .padding(.horizontal)
            }
        }
    }
    
    // Replace the entire `generateAIDialogueButton` definition with this:

    private var generateAIDialogueButton: some View {
        return Button(action: {
            generateBANTDialogue()
        }) {
            Text("Select Qualification Questions")
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
}



