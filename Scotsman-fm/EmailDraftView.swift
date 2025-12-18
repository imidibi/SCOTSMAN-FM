//
//  EmailDraftView.swift
//  SalesDiver
//
//  Created by Ian Miller on 4/30/25.
//

import SwiftUI

struct EmailDraftView: View {
    let contactEmail: String
    let ccEmail: String? = nil
    let bccEmail: String? = nil
    let contactFirstName: String
    let subject: String
    let companyName: String
    let opportunityName: String
    let followUpName: String
    let dueDate: Date
    @Binding var emailText: String
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Group {
                    Text("To:")
                        .font(.headline)
                    Text(contactEmail)
                        .padding(.bottom, 5)

                    if let cc = ccEmail, !cc.isEmpty {
                        Text("CC:")
                            .font(.headline)
                        Text(cc)
                            .padding(.bottom, 5)
                    }
                    if let bcc = bccEmail, !bcc.isEmpty {
                        Text("BCC:")
                            .font(.headline)
                        Text(bcc)
                            .padding(.bottom, 5)
                    }

                    Text("Subject:")
                        .font(.headline)
                    TextField("Subject", text: .constant(subject))
                        .disabled(true)
                        .padding(.bottom, 5)

                    Text("Body:")
                        .font(.headline)
                }

                TextEditor(text: $emailText)
                    .border(Color.gray.opacity(0.5), width: 1)
                    .padding(.bottom, 20)

                Spacer()

                HStack {
                    Button("Cancel") {
                        isPresented = false
                        onDismiss?()
                    }
                    .foregroundColor(.red)

                    Spacer()

                    Button("Send Email") {
                        // print("Composing email to: \(contactEmail)")
                        // print("Subject: \(subject)")
                        // print("Body: \(emailText)")
                        if let emailUrl = createEmailUrl(to: contactEmail, subject: subject, body: emailText) {
                            if UIApplication.shared.canOpenURL(emailUrl) {
                                UIApplication.shared.open(emailUrl)
                            }
                        }
                        isPresented = false
                    }
                    .disabled(contactEmail.isEmpty)
                }
            }
            .padding()
            .navigationTitle("Email Draft")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                        onDismiss?()
                    }
                }
            }
            .onAppear {
                if emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let fallback = "Not Provided"
                    let name = contactFirstName.isEmpty ? fallback : contactFirstName
                    let followup = followUpName.isEmpty ? fallback : followUpName
                    let company = companyName.isEmpty ? fallback : companyName
                    let opportunity = opportunityName.isEmpty ? fallback : opportunityName
                    let formattedDate = dueDate.formatted(date: .long, time: .omitted)

                    emailText = """
                    Dear \(name),

                    This is a follow-up regarding "\(followup)" for \(company), specifically related to \(opportunity).
                    
                    The due date for this follow-up is \(formattedDate).

                    Please take the necessary actions and update me with the status accordingly.

                    Best regards,
                    """
                }
            }
        }
    }

    private func createEmailUrl(to: String, subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = to
        var queryItems = [URLQueryItem(name: "subject", value: subject),
                          URLQueryItem(name: "body", value: body)]
        if let cc = ccEmail, !cc.isEmpty {
            queryItems.append(URLQueryItem(name: "cc", value: cc))
        }
        if let bcc = bccEmail, !bcc.isEmpty {
            queryItems.append(URLQueryItem(name: "bcc", value: bcc))
        }
        components.queryItems = queryItems
        return components.url
    }
}
