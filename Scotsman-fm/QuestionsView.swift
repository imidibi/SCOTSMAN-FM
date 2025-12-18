import SwiftUI
import CoreData

struct QuestionsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var questions: [BANTQuestion] = []
    @State private var selectedCategory: String = ""
    @State private var questionText: String = ""
    @State private var isEditing: Bool = false
    @State private var editingQuestion: BANTQuestion?
    @State private var showResetConfirmation = false


    @AppStorage("selectedMethodology") private var selectedMethodology = "BANT"

    private var categories: [String] {
        switch selectedMethodology {
        case "MEDDIC":
            return ["Metrics", "Economic Buyer", "Decision Criteria", "Decision Process", "Identify Pain", "Champion"]
        case "SCUBATANK":
            return ["Solution", "Competition", "Uniques", "Benefits", "Authority", "Timescale", "Action Plan", "Need", "Kash"]
        default:
            return ["Budget", "Authority", "Need", "Timescale"]
        }
    }

    private var icons: [String] {
        switch selectedMethodology {
        case "MEDDIC":
            return ["m.circle.fill", "e.circle.fill", "d.circle.fill", "d.circle.fill", "i.circle.fill", "c.circle.fill"]
        case "SCUBATANK":
            return ["s.circle.fill", "c.circle.fill", "u.circle.fill", "b.circle.fill", "a.circle.fill", "t.circle.fill", "a.circle.fill", "n.circle.fill", "k.circle.fill"]
        default:
            return ["b.circle.fill", "a.circle.fill", "n.circle.fill", "t.circle.fill"]
        }
    }

    init() {
        loadDefaultQuestions()
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Questions")
                .font(.largeTitle)
                .bold()
                .padding()
            
            categorySelectionView
            questionInputView
            questionListView
        }
        .padding()
        .onAppear { loadQuestions() }
    }
    
    private var categorySelectionView: some View {
        VStack {
            HStack(spacing: 15) {
                ForEach(Array(categories.enumerated()), id: \.0) { index, category in
                    Button(action: {
                        selectedCategory = category
                        loadQuestions(filterCategory: category)
                    }) {
                        Image(systemName: icons[index])
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(selectedCategory == category ? .blue : .gray)
                    }
                }
            }
            .padding()
            if !selectedCategory.isEmpty {
                Text(selectedCategory)
                    .font(.headline)
                    .padding(.top, 5)
            }
        }
    }
    
    private var questionInputView: some View {
        VStack {
            TextField("Enter New Question", text: $questionText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: saveQuestion) {
                Text(isEditing ? "Update Question" : "Add Question")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            Button(action: {
                showResetConfirmation = true
            }) {
                Text("Reset to Default Questions")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .alert(isPresented: $showResetConfirmation) {
                Alert(
                    title: Text("Reset Confirmation"),
                    message: Text("Are you sure you want to reset to the default questions? This will overwrite your existing questions."),
                    primaryButton: .destructive(Text("Reset"), action: {
                        loadDefaultQuestions()
                        loadQuestions()
                    }),
                    secondaryButton: .cancel()
                )
            }
        }
        .padding()
    }
    
    private var questionListView: some View {
        List {
            ForEach(questions, id: \.id) { question in
                HStack {
                    Text(String(question.category?.prefix(1) ?? "?"))
                        .font(.title)
                        .bold()
                        .foregroundColor(.blue)
                    
                    Text(question.questionText ?? "")
                        .font(.body)
                    
                    Spacer()
                    
                    Button(action: { editQuestion(question) }) {
                        Image(systemName: "pencil.circle.fill").foregroundColor(.orange)
                    }
                    Button(action: { deleteQuestion(question) }) {
                        Image(systemName: "trash.fill").foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private func saveQuestion() {
        if let editingQuestion = editingQuestion, editingQuestion.managedObjectContext != nil {
            editingQuestion.questionText = questionText
        } else {
            let newQuestion = BANTQuestion(context: CoreDataManager.shared.context)
            newQuestion.id = UUID()
            newQuestion.category = selectedCategory
            newQuestion.questionText = questionText
            questions.append(newQuestion)
        }
        do {
            try CoreDataManager.shared.context.save()
        } catch {
            // print("Failed to save Core Data: \(error.localizedDescription)")
        }
        resetForm()
        loadQuestions()
    }
    
    private func loadQuestions(filterCategory: String? = nil) {
        let fetchRequest: NSFetchRequest<BANTQuestion> = BANTQuestion.fetchRequest()
        if let allQuestions = try? CoreDataManager.shared.context.fetch(fetchRequest) {
            var filtered = allQuestions.filter {
                guard let category = $0.category else { return false }
                return categories.contains(category)
            }

            if let filter = filterCategory {
                filtered = filtered.filter { $0.category == filter }
            }

            questions = filtered.sorted {
                guard let firstCategory = $0.category,
                      let secondCategory = $1.category,
                      let firstIndex = categories.firstIndex(of: firstCategory),
                      let secondIndex = categories.firstIndex(of: secondCategory)
                else { return false }
                return firstIndex < secondIndex
            }
        }
    }

    private func editQuestion(_ question: BANTQuestion) {
        questionText = question.questionText ?? ""
        selectedCategory = question.category ?? "Budget"
        editingQuestion = question
        isEditing = true
    }

    private func deleteQuestion(_ question: BANTQuestion) {
        CoreDataManager.shared.context.delete(question)
        do {
            try CoreDataManager.shared.context.save()
        } catch {
            // print("Failed to save Core Data: \(error.localizedDescription)")
        }
        loadQuestions()
    }

    private func resetForm() {
        questionText = ""
        isEditing = false
        editingQuestion = nil
    }

    private func loadDefaultQuestions() {
        let fetchRequest: NSFetchRequest<BANTQuestion> = BANTQuestion.fetchRequest()
        if let existingQuestions = try? CoreDataManager.shared.context.fetch(fetchRequest) {
            for question in existingQuestions {
                CoreDataManager.shared.context.delete(question)
            }
        }

        let defaults: [(String, String)] = [
            // BANT Questions
            ("Budget", "What budget has been allocated for this project or solution?"),
            ("Budget", "Are there any financial constraints we should be aware of?"),
            ("Budget", "How does this investment compare to other priorities within your organization?"),
            ("Budget", "Have you made similar purchases before? If so, what was your budget range?"),
            ("Budget", "Would you need internal approvals or additional funding to move forward?"),
            ("Authority", "Who is responsible for making the final decision on this purchase?"),
            ("Authority", "Are there any other stakeholders involved in the approval process?"),
            ("Authority", "Have you gone through a similar purchasing process before? How did it work?"),
            ("Authority", "Do you have the authority to sign off on this purchase, or is there a committee involved?"),
            ("Authority", "What criteria do decision-makers prioritize when evaluating solutions like this?"),
            ("Need", "What specific problem or challenge are you trying to solve?"),
            ("Need", "How are you currently handling this issue, and what are the limitations?"),
            ("Need", "What impact would solving this problem have on your business?"),
            ("Need", "What features or capabilities are most important in a solution?"),
            ("Need", "What would happen if you didn’t address this need?"),
            ("Timescale", "When are you looking to implement this solution?"),
            ("Timescale", "Are there any deadlines or external factors driving this timeline?"),
            ("Timescale", "How long has this issue been a priority for your company?"),
            ("Timescale", "Are there any internal approvals or processes that could delay implementation?"),
            ("Timescale", "What is your ideal timeline for seeing results from this investment?"),

            // MEDDIC Questions
            ("Metrics", "What key metrics are you looking to improve with this solution?"),
            ("Metrics", "How do you currently measure success in this area?"),
            ("Metrics", "What are your target performance improvements or KPIs?"),
            ("Metrics", "How will you quantify the ROI of this investment?"),
            ("Metrics", "What financial or operational benchmarks are you aiming to achieve?"),
            ("Economic Buyer", "Who controls the budget for this purchase?"),
            ("Economic Buyer", "What are this person’s top priorities or concerns?"),
            ("Economic Buyer", "Have they been involved in similar decisions before?"),
            ("Economic Buyer", "What would make this investment a clear win for them?"),
            ("Economic Buyer", "What are the best ways to engage and involve the economic buyer?"),
            ("Decision Criteria", "What criteria will you use to compare solutions?"),
            ("Decision Criteria", "How important are price, features, and vendor reputation in your decision?"),
            ("Decision Criteria", "What functional or technical requirements must be met?"),
            ("Decision Criteria", "What compliance or industry standards are involved?"),
            ("Decision Criteria", "Who defined these criteria and how were they prioritized?"),
            ("Decision Process", "What is your internal process for making a purchase decision?"),
            ("Decision Process", "What are the key milestones and approval steps?"),
            ("Decision Process", "Who are the stakeholders involved in this process?"),
            ("Decision Process", "Are there formal review committees or legal reviews required?"),
            ("Decision Process", "How long does a typical purchase decision take in your organization?"),
            ("Identify Pain", "What specific business challenges are you trying to solve?"),
            ("Identify Pain", "What are the consequences if these issues remain unaddressed?"),
            ("Identify Pain", "How is this pain impacting your team or customers?"),
            ("Identify Pain", "What have you tried so far to resolve this challenge?"),
            ("Identify Pain", "Why is solving this now a priority for you?"),
            ("Champion", "Who within your organization is advocating for this solution?"),
            ("Champion", "How influential is this person in the decision-making process?"),
            ("Champion", "What are their personal or professional motivations?"),
            ("Champion", "What support do they need to build internal consensus?"),
            ("Champion", "How can we help them succeed as your internal champion?"),

            // SCUBATANK Questions
            ("Solution", "Has the customer confirmed that the solution you are proposing will do the job?"),
            ("Solution", "Have you validated the solution against all of the client’s stated requirements?"),
            ("Solution", "Has the customer acknowledged your solution’s fit with their environment?"),
            ("Solution", "Have you demonstrated the solution in action?"),
            ("Solution", "Has the client shared any gaps or concerns about your proposed solution?"),
            ("Competition", "Do you know who you are up against?"),
            ("Competition", "Have you identified the competitors being evaluated?"),
            ("Competition", "What perceived advantages do competitors have?"),
            ("Competition", "Have you assessed how the client views competitors?"),
            ("Competition", "Are there internal alternatives being considered?"),
            ("Uniques", "Have you identified elements that make you stand out?"),
            ("Uniques", "Can you articulate your unique differentiators?"),
            ("Uniques", "Has the client acknowledged your differentiators?"),
            ("Uniques", "Have you mapped your strengths to client priorities?"),
            ("Uniques", "Are your differentiators defensible against competitive claims?"),
            ("Benefits", "Have you clearly articulated the tangible benefits?"),
            ("Benefits", "Have you quantified the impact of these benefits?"),
            ("Benefits", "Has the client validated these benefits?"),
            ("Benefits", "Are benefits aligned with client success metrics?"),
            ("Benefits", "Have you connected benefits to stakeholder priorities?"),
            ("Authority", "Have you met the individual with budget authority?"),
            ("Authority", "Do you understand how they evaluate investments?"),
            ("Authority", "Have you involved all influencers?"),
            ("Authority", "Are there multiple decision-makers to align with?"),
            ("Authority", "Have you mapped out the decision-making hierarchy?"),
            ("Timescale", "When does the client need the solution implemented?"),
            ("Timescale", "What events are driving this timeline?"),
            ("Timescale", "Are there specific project milestones?"),
            ("Timescale", "What risks could delay implementation?"),
            ("Timescale", "How does this timeline compare to delivery capacity?"),
            ("Action Plan", "Have you scheduled touch points with the client?"),
            ("Action Plan", "Does the client agree to the next steps and timeline?"),
            ("Action Plan", "Have you defined ownership for each step?"),
            ("Action Plan", "Are stakeholders committed to scheduled meetings?"),
            ("Action Plan", "Have you aligned the action plan with procurement?"),
            ("Need", "Do you know the specific problems the prospect is facing?"),
            ("Need", "Has the client prioritized these needs?"),
            ("Need", "Are these needs urgent or mission-critical?"),
            ("Need", "Have you uncovered the root cause?"),
            ("Need", "Have you validated your solution addresses these needs?"),
            ("Kash", "Is the client’s budget adequate to meet their needs?"),
            ("Kash", "Have they confirmed the available budget range?"),
            ("Kash", "What internal approval processes govern the budget?"),
            ("Kash", "Have you discussed the budget with the economic buyer?"),
            ("Kash", "Is there flexibility in the budget if value is demonstrated?")
        ]

        for (category, text) in defaults {
            let newQuestion = BANTQuestion(context: CoreDataManager.shared.context)
            newQuestion.id = UUID()
            newQuestion.category = category
            newQuestion.questionText = text
        }

        do {
            try CoreDataManager.shared.context.save()
        } catch {
            // print("Failed to save default questions: \(error.localizedDescription)")
        }
    }
}

struct QuestionsView_Previews: PreviewProvider {
    static var previews: some View {
        QuestionsView()
    }
}
