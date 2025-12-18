import SwiftUI
import CoreData

struct RecordMeetingView: View {
    let meeting: MeetingsEntity
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    @State private var currentQuestionIndex = 0
    @StateObject private var speechManager = SpeechManager()
    @State private var currentAnswer = ""
    @AppStorage("selectedMethodology") private var currentMethodology: String = "BANT"

    @ViewBuilder
    private var qualificationIndicatorView: some View {
        if let opportunityEntity = meeting.opportunity {
            let wrapper = OpportunityWrapper(managedObject: opportunityEntity)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Meeting Info Header
            Group {
                Text(meeting.title ?? "Untitled Meeting")
                    .font(.title)
                    .bold()

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

                qualificationIndicatorView
                    .scaleEffect(0.8)
            }

            Divider()

            // Question and Answer Section
            let sortedQuestions = (meeting.questions as? Set<MeetingQuestionEntity>)?.sorted { ($0.questionText ?? "") < ($1.questionText ?? "") } ?? []

            if currentQuestionIndex < sortedQuestions.count {
                let question = sortedQuestions[currentQuestionIndex]

                ZStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Question \(currentQuestionIndex + 1) of \(sortedQuestions.count):")
                            .font(.headline)

                        Text(question.questionText ?? "")
                            .font(.body)

                        TextEditor(text: $speechManager.transcribedText)
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
                            .onChange(of: speechManager.transcribedText) {
                                currentAnswer = speechManager.transcribedText
                            }

                        Button(action: {
                            // Example flagging action - you might expand this logic
                            question.answer = (question.answer ?? "") + "\n[INSIGHT] " + currentAnswer
                            do {
                                try viewContext.save()
                            } catch {
                                // print("Error saving flagged insight: \(error.localizedDescription)")
                            }
                        }) {
                            Label("Pin Insight", systemImage: "star.fill")
                                .foregroundColor(.yellow)
                        }
                        .padding(.top, 4)

                        if (UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .phone),
                           !ProcessInfo.processInfo.isiOSAppOnMac {
                            HStack {
                                Button(action: {
                                    try? speechManager.startTranscribing()
                                }) {
                                    Image(systemName: "record.circle.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.red)
                                }
                                .disabled(!speechManager.isTranscribingAvailable)

                                Button(action: {
                                    speechManager.stopTranscribing()
                                }) {
                                    Image(systemName: "stop.circle.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.gray)
                                }
                                .disabled(!speechManager.isRecording)
                            }
                        }

                        // Optional Handwriting Area
                        NavigationLink(destination: HandwritingCaptureView(onSave: { handwritingText in
                            currentAnswer += "\n" + handwritingText
                            speechManager.transcribedText = currentAnswer
                        })) {
                            Text("Add Handwritten Notes")
                                .font(.body)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        }

                        HStack {
                            Button("Previous Question") {
                                let question = sortedQuestions[currentQuestionIndex]
                                question.answer = currentAnswer
                                do {
                                    try viewContext.save()
                                } catch {
                                    // print("Error saving answer: \(error.localizedDescription)")
                                }
                                speechManager.stopTranscribing()
                                if currentQuestionIndex > 0 {
                                    currentQuestionIndex -= 1
                                    let previousQuestion = sortedQuestions[currentQuestionIndex]
                                    currentAnswer = previousQuestion.answer ?? ""
                                    speechManager.transcribedText = currentAnswer
                                    try? speechManager.startTranscribing()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .padding(.trailing, 8)

                            Button("Next Question") {
                                let question = sortedQuestions[currentQuestionIndex]
                                question.answer = currentAnswer
                                do {
                                    try viewContext.save()
                                } catch {
                                    // print("Error saving answer: \(error.localizedDescription)")
                                }
                                speechManager.stopTranscribing()
                                currentQuestionIndex += 1
                                if currentQuestionIndex < sortedQuestions.count {
                                    let nextQuestion = sortedQuestions[currentQuestionIndex]
                                    currentAnswer = nextQuestion.answer ?? ""
                                    speechManager.transcribedText = currentAnswer
                                    try? speechManager.startTranscribing()
                                } else {
                                    currentAnswer = ""
                                    speechManager.transcribedText = ""
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }
                        .padding(.top)
                    }
                    .onAppear {
                        if currentQuestionIndex == 0 && currentAnswer.isEmpty {
                            currentAnswer = question.answer ?? ""
                            speechManager.transcribedText = currentAnswer
                        }
                    }
                }
            } else {
                Text("All questions answered. Thank you!")
                    .font(.title2)
                    .padding(.top)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Record Meeting")
        .navigationBarBackButtonHidden(false)
    }
}

// Helper DateFormatter for displaying date
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()
