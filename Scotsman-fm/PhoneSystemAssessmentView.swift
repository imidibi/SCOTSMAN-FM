//
//  PhoneSystemAssessmentView.swift
//  SalesDiver
//
//  Created by Ian Miller on 4/19/25.
//
import SwiftUI

struct PhoneSystemAssessmentView: View {
    @AppStorage("selectedCompany") private var selectedCompany: String = ""
    @EnvironmentObject var coreDataManager: CoreDataManager

    @State private var hasVoip = false
    @State private var voipSoftware = ""
    @State private var handsetBrand = ""
    @State private var usesMobileAccess = false
    @State private var satisfied = false
    @State private var dissatisfactionReason = ""
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Phone System Assessment")
                    .font(.largeTitle)
                    .bold()

                GroupBox(label: Label("Phone System Details", systemImage: "phone")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Do you have a VOIP Phone system?", isOn: $hasVoip)

                        Text("What software are you using?")
                        TextField("", text: $voipSoftware)
                            .textFieldStyle(.roundedBorder)

                        Text("What brand are the handsets?")
                        TextField("", text: $handsetBrand)
                            .textFieldStyle(.roundedBorder)

                        Toggle("Do employees use mobile devices to access the phone system?", isOn: $usesMobileAccess)

                        Toggle("Are you happy with your phone service?", isOn: $satisfied)

                        Text("If not, why?")
                        TextField("", text: $dissatisfactionReason)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.top, 5)
                }

                Button("Save") {
                    guard !selectedCompany.isEmpty, !isSaving else { return }
                    isSaving = true
                    let fields: [(String, String?, Bool?)] = [
                        ("Has VOIP", nil, hasVoip),
                        ("VOIP Software", voipSoftware.isEmpty ? nil : voipSoftware, nil),
                        ("Handset Brand", handsetBrand.isEmpty ? nil : handsetBrand, nil),
                        ("Uses Mobile Access", nil, usesMobileAccess),
                        ("Phone Satisfied", nil, satisfied),
                        ("Phone Dissatisfaction Reason", dissatisfactionReason.isEmpty ? nil : dissatisfactionReason, nil)
                    ]
                    coreDataManager.saveAssessmentFields(for: selectedCompany, category: "Phone", fields: fields)
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
            let fields = coreDataManager.loadAllAssessmentFields(for: selectedCompany, category: "Phone")
            for field in fields {
                switch field.fieldName {
                case "Has VOIP": hasVoip = field.valueString == "true"
                case "VOIP Software": voipSoftware = field.valueString ?? ""
                case "Handset Brand": handsetBrand = field.valueString ?? ""
                case "Uses Mobile Access": usesMobileAccess = field.valueString == "true"
                case "Phone Satisfied": satisfied = field.valueString != "false"
                case "Phone Dissatisfaction Reason": dissatisfactionReason = field.valueString ?? ""
                default: break
                }
            }
        }
    }
}
