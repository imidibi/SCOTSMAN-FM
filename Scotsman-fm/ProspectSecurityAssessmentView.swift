//
//  ProspectSecurityAssessmentView.swift
//  SalesDiver
//
//  Created by Ian Miller on 4/19/25.
//
import SwiftUI

struct ProspectSecurityAssessmentView: View {
    @AppStorage("selectedCompany") private var selectedCompany: String = ""
    @EnvironmentObject var coreDataManager: CoreDataManager

    // All @State fields (trimmed here for brevity)
    @State private var experiencedAttack = false
    @State private var attackDescription = ""
    @State private var recoveryTime = ""
    @State private var businessImpact = ""
    @State private var wellSecured = false
    @State private var hasAV = false
    @State private var avSolution = ""
    @State private var hasEDR = false
    @State private var edrSolution = ""
    @State private var hasEmailSecurity = false
    @State private var emailSecuritySolution = ""
    @State private var hasSIEM = false
    @State private var siemSolution = ""
    @State private var hasTraining = false
    @State private var trainingSolution = ""
    @State private var hasDNSProtection = false
    @State private var dnsSolution = ""
    @State private var hasMFA = false
    @State private var mfaHow = ""
    @State private var mfaEnforced = false
    @State private var mfaEnforcedHow = ""
    @State private var hasMDM = false
    @State private var mdmSolution = ""
    @State private var allowsPersonalMobile = false
    @State private var hasAUP = false
    @State private var lockedServers = false
    @State private var hasPhysicalSecurity = false
    @State private var physicalSecuritySolution = ""
    @State private var getsDarkWebReports = false
    @State private var hasPasswordPolicy = false
    @State private var hasCyberInsurance = false
    @State private var insuranceRenewal = ""
    @State private var interestedInAssessment = false
    @State private var isSaving = false
    @State private var hasComplianceObligations = false
    @State private var compliesWithHIPAA = false
    @State private var compliesWithPCI = false
    @State private var compliesWithFINRA = false
    @State private var compliesWithOther = false
    @State private var otherComplianceDetails = ""
    @State private var isCurrentlyCompliant = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Security & Compliance Assessment")
                    .font(.largeTitle)
                    .bold()

                GroupBox(label: Label("Incident History", systemImage: "exclamationmark.triangle")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Have you experienced a cyber-security attack?", isOn: $experiencedAttack)
                        Text("Please describe what happened?")
                        TextField("", text: $attackDescription).textFieldStyle(.roundedBorder)
                        Text("How long did it take you to recover?")
                        TextField("", text: $recoveryTime).textFieldStyle(.roundedBorder)
                        Text("What was the impact on your business?")
                        TextField("", text: $businessImpact).textFieldStyle(.roundedBorder)
                        Toggle("Do you consider your company as well secured?", isOn: $wellSecured)
                    }
                }

                GroupBox(label: Label("Security Tools", systemImage: "shield.lefthalf.fill")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Do you have an AV solution in place?", isOn: $hasAV)
                        Text("Which one?")
                        TextField("", text: $avSolution).textFieldStyle(.roundedBorder)

                        Toggle("Do you have End Point Detection and Response in place?", isOn: $hasEDR)
                        Text("Which one?")
                        TextField("", text: $edrSolution).textFieldStyle(.roundedBorder)

                        Toggle("Do you have an email security solution?", isOn: $hasEmailSecurity)
                        Text("Which one?")
                        TextField("", text: $emailSecuritySolution).textFieldStyle(.roundedBorder)

                        Toggle("Do you have a SIEM Solution?", isOn: $hasSIEM)
                        Text("Which one?")
                        TextField("", text: $siemSolution).textFieldStyle(.roundedBorder)

                        Toggle("Do you have cyber-security training?", isOn: $hasTraining)
                        Text("Which one?")
                        TextField("", text: $trainingSolution).textFieldStyle(.roundedBorder)

                        Toggle("Do you have DNS protection?", isOn: $hasDNSProtection)
                        Text("Which one?")
                        TextField("", text: $dnsSolution).textFieldStyle(.roundedBorder)
                    }
                }

                GroupBox(label: Label("Access Controls", systemImage: "lock")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Are your apps and email protected by MFA?", isOn: $hasMFA)
                        Text("How?")
                        TextField("", text: $mfaHow).textFieldStyle(.roundedBorder)

                        Toggle("Is MFA enforced for all users?", isOn: $mfaEnforced)
                        Text("How?")
                        TextField("", text: $mfaEnforcedHow).textFieldStyle(.roundedBorder)

                        Toggle("Do you have a mobile device management solution?", isOn: $hasMDM)
                        Text("Which one?")
                        TextField("", text: $mdmSolution).textFieldStyle(.roundedBorder)

                        Toggle("Do you allow employees to access email or company files on their own mobile devices?", isOn: $allowsPersonalMobile)
                        Toggle("Do you have a published Acceptable Use Policy?", isOn: $hasAUP)
                    }
                }

                GroupBox(label: Label("Physical Security", systemImage: "key")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Are your server and network equipment secured by a lock?", isOn: $lockedServers)
                        Toggle("Do you have any physical security such as camera systems and key codes?", isOn: $hasPhysicalSecurity)
                        Text("Which one?")
                        TextField("", text: $physicalSecuritySolution).textFieldStyle(.roundedBorder)
                    }
                }

                GroupBox(label: Label("Policy & Risk", systemImage: "doc.plaintext")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Do you receive reports on your credentials being traded on the dark web?", isOn: $getsDarkWebReports)
                        Toggle("Do you have an enforced password policy?", isOn: $hasPasswordPolicy)
                        Toggle("Do you have a cyber-insurance policy in place?", isOn: $hasCyberInsurance)
                        Text("When is it renewed?")
                        TextField("", text: $insuranceRenewal).textFieldStyle(.roundedBorder)
                        
                        GroupBox(label: Label("Compliance", systemImage: "checkmark.shield")) {
                            VStack(alignment: .leading, spacing: 15) {
                                Toggle("Does your organization have compliance obligations?", isOn: $hasComplianceObligations)
                                Toggle("HIPAA?", isOn: $compliesWithHIPAA)
                                Toggle("PCI?", isOn: $compliesWithPCI)
                                Toggle("FINRA?", isOn: $compliesWithFINRA)
                                Toggle("Other?", isOn: $compliesWithOther)
                                Text("Which?")
                                TextField("", text: $otherComplianceDetails).textFieldStyle(.roundedBorder)
                                Toggle("Are you currently compliant?", isOn: $isCurrentlyCompliant)
                            }
                        }

                        Toggle("Are you interested in a comprehensive security assessment?", isOn: $interestedInAssessment)
                    }
                }

                Button("Save") {
                    guard !selectedCompany.isEmpty, !isSaving else { return }
                    isSaving = true
                    let fields: [(String, String?, Bool?)] = [
                        ("Experienced Attack", nil, experiencedAttack),
                        ("Attack Description", attackDescription, nil),
                        ("Recovery Time", recoveryTime, nil),
                        ("Business Impact", businessImpact, nil),
                        ("Well Secured", nil, wellSecured),
                        ("Has AV", nil, hasAV),
                        ("AV Solution", avSolution, nil),
                        ("Has EDR", nil, hasEDR),
                        ("EDR Solution", edrSolution, nil),
                        ("Has Email Security", nil, hasEmailSecurity),
                        ("Email Security Solution", emailSecuritySolution, nil),
                        ("Has SIEM", nil, hasSIEM),
                        ("SIEM Solution", siemSolution, nil),
                        ("Has Training", nil, hasTraining),
                        ("Training Solution", trainingSolution, nil),
                        ("Has DNS Protection", nil, hasDNSProtection),
                        ("DNS Solution", dnsSolution, nil),
                        ("Has MFA", nil, hasMFA),
                        ("MFA How", mfaHow, nil),
                        ("MFA Enforced", nil, mfaEnforced),
                        ("MFA Enforced How", mfaEnforcedHow, nil),
                        ("Has MDM", nil, hasMDM),
                        ("MDM Solution", mdmSolution, nil),
                        ("Allows Personal Mobile", nil, allowsPersonalMobile),
                        ("Has AUP", nil, hasAUP),
                        ("Locked Servers", nil, lockedServers),
                        ("Has Physical Security", nil, hasPhysicalSecurity),
                        ("Physical Security Solution", physicalSecuritySolution, nil),
                        ("Gets Dark Web Reports", nil, getsDarkWebReports),
                        ("Has Password Policy", nil, hasPasswordPolicy),
                        ("Has Cyber Insurance", nil, hasCyberInsurance),
                        ("Insurance Renewal", insuranceRenewal, nil),
                        ("Has Compliance Obligations", nil, hasComplianceObligations),
                        ("Complies With HIPAA", nil, compliesWithHIPAA),
                        ("Complies With PCI", nil, compliesWithPCI),
                        ("Complies With FINRA", nil, compliesWithFINRA),
                        ("Complies With Other", nil, compliesWithOther),
                        ("Other Compliance Details", otherComplianceDetails, nil),
                        ("Is Currently Compliant", nil, isCurrentlyCompliant),
                        ("Interested In Assessment", nil, interestedInAssessment)
                    ]
                    coreDataManager.saveAssessmentFields(for: selectedCompany, category: "Security & Compliance", fields: fields)
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
            let fields = coreDataManager.loadAllAssessmentFields(for: selectedCompany, category: "Security & Compliance")
            for field in fields {
                switch field.fieldName {
                case "Experienced Attack": experiencedAttack = field.valueString == "true"
                case "Attack Description": attackDescription = field.valueString ?? ""
                case "Recovery Time": recoveryTime = field.valueString ?? ""
                case "Business Impact": businessImpact = field.valueString ?? ""
                case "Well Secured": wellSecured = field.valueString == "true"
                case "Has AV": hasAV = field.valueString == "true"
                case "AV Solution": avSolution = field.valueString ?? ""
                case "Has EDR": hasEDR = field.valueString == "true"
                case "EDR Solution": edrSolution = field.valueString ?? ""
                case "Has Email Security": hasEmailSecurity = field.valueString == "true"
                case "Email Security Solution": emailSecuritySolution = field.valueString ?? ""
                case "Has SIEM": hasSIEM = field.valueString == "true"
                case "SIEM Solution": siemSolution = field.valueString ?? ""
                case "Has Training": hasTraining = field.valueString == "true"
                case "Training Solution": trainingSolution = field.valueString ?? ""
                case "Has DNS Protection": hasDNSProtection = field.valueString == "true"
                case "DNS Solution": dnsSolution = field.valueString ?? ""
                case "Has MFA": hasMFA = field.valueString == "true"
                case "MFA How": mfaHow = field.valueString ?? ""
                case "MFA Enforced": mfaEnforced = field.valueString == "true"
                case "MFA Enforced How": mfaEnforcedHow = field.valueString ?? ""
                case "Has MDM": hasMDM = field.valueString == "true"
                case "MDM Solution": mdmSolution = field.valueString ?? ""
                case "Allows Personal Mobile": allowsPersonalMobile = field.valueString == "true"
                case "Has AUP": hasAUP = field.valueString == "true"
                case "Locked Servers": lockedServers = field.valueString == "true"
                case "Has Physical Security": hasPhysicalSecurity = field.valueString == "true"
                case "Physical Security Solution": physicalSecuritySolution = field.valueString ?? ""
                case "Gets Dark Web Reports": getsDarkWebReports = field.valueString == "true"
                case "Has Password Policy": hasPasswordPolicy = field.valueString == "true"
                case "Has Cyber Insurance": hasCyberInsurance = field.valueString == "true"
                case "Insurance Renewal": insuranceRenewal = field.valueString ?? ""
                case "Has Compliance Obligations": hasComplianceObligations = field.valueString == "true"
                case "Complies With HIPAA": compliesWithHIPAA = field.valueString == "true"
                case "Complies With PCI": compliesWithPCI = field.valueString == "true"
                case "Complies With FINRA": compliesWithFINRA = field.valueString == "true"
                case "Complies With Other": compliesWithOther = field.valueString == "true"
                case "Other Compliance Details": otherComplianceDetails = field.valueString ?? ""
                case "Is Currently Compliant": isCurrentlyCompliant = field.valueString == "true"
                case "Interested In Assessment": interestedInAssessment = field.valueString == "true"
                default: break
                }
            }
        }
    }
}
