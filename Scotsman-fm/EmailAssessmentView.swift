//
//  EmailAssessmentView.swift
//  SalesDiver
//
//  Created by Ian Miller on 4/19/25.
//
import SwiftUI

struct EmailAssessmentView: View {
    @AppStorage("selectedCompany") private var selectedCompany: String = ""
    @EnvironmentObject var coreDataManager: CoreDataManager

    @State private var selectedEmailProvider: String = ""
    @State private var selectedAuthenticationMethod: String = ""
    @State private var hasMFA = false
    @State private var hasEmailSecurity = false
    @State private var emailSecurityBrand = ""
    @State private var experiencesPhishing = false
    @State private var backsUpEmail = false
    @State private var emailBackupMethod = ""
    @State private var fileSharingMethod = ""
    @State private var emailMalware = false
    @State private var malwareDetails = ""
    @State private var satisfactionText = ""
    @State private var isSaving = false
    @State private var employeeCount = ""
    @State private var allHaveEmail = true
    @State private var withEmailCount = ""
    @State private var licenseTypes = ""

    let allEmailProviders = ["Microsoft 365", "Google Workspace", "GoDaddy", "Proton", "MS Exchange", "Other"]
    let allAuthMethods = ["Active Directory", "Entra ID", "JumpCloud", "Other"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Email Assessment")
                    .font(.largeTitle)
                    .bold()

                GroupBox(label: Label("Email Platform", systemImage: "envelope")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Who is your email provider?")
                        Picker("Email Provider", selection: $selectedEmailProvider) {
                            ForEach(allEmailProviders, id: \.self) { provider in
                                Text(provider).tag(provider)
                            }
                        }
                        .pickerStyle(.menu)

                        Text("How do you authenticate your users?")
                        Picker("Authentication Method", selection: $selectedAuthenticationMethod) {
                            ForEach(allAuthMethods, id: \.self) { method in
                                Text(method).tag(method)
                            }
                        }
                        .pickerStyle(.menu)

                        Toggle("Do you have MFA on your email service?", isOn: $hasMFA)
                    }
                    .padding(.top, 5)
                }

                GroupBox(label: Label("Security & Backup", systemImage: "lock.shield")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Do you have email security tools in place?", isOn: $hasEmailSecurity)
                        Text("If so, which brand?")
                        TextField("", text: $emailSecurityBrand).textFieldStyle(.roundedBorder)

                        Toggle("Do you experience phishing attempts?", isOn: $experiencesPhishing)

                        Toggle("Do you back up your email accounts?", isOn: $backsUpEmail)
                        Text("If so, how?")
                        TextField("", text: $emailBackupMethod).textFieldStyle(.roundedBorder)
                    }
                }

                GroupBox(label: Label("Usage & Satisfaction", systemImage: "person.3")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("How does your team do file sharing?")
                        TextField("", text: $fileSharingMethod).textFieldStyle(.roundedBorder)

                        Toggle("Have you experienced email malware or account takeover?", isOn: $emailMalware)
                        Text("If so, what are the details?")
                        TextField("", text: $malwareDetails).textFieldStyle(.roundedBorder)

                        Text("Are you happy with your email service?")
                        TextField("", text: $satisfactionText).textFieldStyle(.roundedBorder)
                    }
                }

                GroupBox(label: Label("Licensing", systemImage: "person.crop.rectangle.stack")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("How many employees do you have?")
                        TextField("", text: $employeeCount).keyboardType(.numberPad).textFieldStyle(.roundedBorder)

                        Toggle("Do all employees have an email account?", isOn: $allHaveEmail)

                        Text("If not, how many do?")
                        TextField("", text: $withEmailCount).keyboardType(.numberPad).textFieldStyle(.roundedBorder)

                        Text("What license types (e.g. Business Basic, Premium, etc) do you have?")
                        TextField("", text: $licenseTypes).textFieldStyle(.roundedBorder)
                    }
                }

                Button("Save") {
                    guard !selectedCompany.isEmpty, !isSaving else { return }
                    isSaving = true
                    let fields: [(String, String?, Bool?)] = [
                        ("Email Providers", selectedEmailProvider, nil),
                        ("Authentication Methods", selectedAuthenticationMethod, nil),
                        ("Has MFA", nil, hasMFA),
                        ("Has Email Security", nil, hasEmailSecurity),
                        ("Email Security Brand", emailSecurityBrand.isEmpty ? nil : emailSecurityBrand, nil),
                        ("Phishing Attempts", nil, experiencesPhishing),
                        ("Backs Up Email", nil, backsUpEmail),
                        ("Email Backup Method", emailBackupMethod.isEmpty ? nil : emailBackupMethod, nil),
                        ("File Sharing Method", fileSharingMethod.isEmpty ? nil : fileSharingMethod, nil),
                        ("Email Malware", nil, emailMalware),
                        ("Malware Details", malwareDetails.isEmpty ? nil : malwareDetails, nil),
                        ("Email Satisfaction", satisfactionText.isEmpty ? nil : satisfactionText, nil),
                        ("Employee Count", employeeCount.isEmpty ? nil : employeeCount, nil),
                        ("All Have Email", nil, allHaveEmail),
                        ("With Email Count", withEmailCount.isEmpty ? nil : withEmailCount, nil),
                        ("Email License Types", licenseTypes.isEmpty ? nil : licenseTypes, nil)
                    ]
                    coreDataManager.saveAssessmentFields(for: selectedCompany, category: "Email", fields: fields)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        isSaving = false
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSaving ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .scaleEffect(isSaving ? 0.97 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSaving)
                .disabled(selectedCompany.isEmpty || isSaving)
            }
            .padding()
        }
        .onAppear {
            guard !selectedCompany.isEmpty else { return }
            let fields = coreDataManager.loadAllAssessmentFields(for: selectedCompany, category: "Email")
            for field in fields {
                switch field.fieldName {
                case "Email Providers": selectedEmailProvider = field.valueString ?? ""
                case "Authentication Methods": selectedAuthenticationMethod = field.valueString ?? ""
                case "Has MFA": hasMFA = field.valueString == "true"
                case "Has Email Security": hasEmailSecurity = field.valueString == "true"
                case "Email Security Brand": emailSecurityBrand = field.valueString ?? ""
                case "Phishing Attempts": experiencesPhishing = field.valueString == "true"
                case "Backs Up Email": backsUpEmail = field.valueString == "true"
                case "Email Backup Method": emailBackupMethod = field.valueString ?? ""
                case "File Sharing Method": fileSharingMethod = field.valueString ?? ""
                case "Email Malware": emailMalware = field.valueString == "true"
                case "Malware Details": malwareDetails = field.valueString ?? ""
                case "Email Satisfaction": satisfactionText = field.valueString ?? ""
                case "Employee Count": employeeCount = field.valueString ?? ""
                case "All Have Email": allHaveEmail = field.valueString != "false"
                case "With Email Count": withEmailCount = field.valueString ?? ""
                case "Email License Types": licenseTypes = field.valueString ?? ""
                default: break
                }
            }
        }
    }
}
