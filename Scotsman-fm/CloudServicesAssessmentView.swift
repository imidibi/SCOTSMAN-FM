//
//  CloudServicesAssessmentView.swift
//  SalesDiver
//
//  Created by Ian Miller on 4/20/25.
//

import SwiftUI

struct CloudServicesAssessmentView: View {
    let coreDataManager = CoreDataManager.shared
    let companyName: String

    @State private var emailAndFileSharingCloud = false
    @State private var cloudServiceUsed = ""
    @State private var usesCloudInfrastructure = false
    @State private var selectedCloudProvider = "Azure"
    @State private var usesServers = false
    @State private var serverQuantity = ""
    @State private var usesStorage = false
    @State private var storageCapacity = ""
    @State private var usesFirewalls = false
    @State private var firewallDetails = ""
    @State private var usesOther = false
    @State private var otherDetails = ""
    @State private var usesCloudManagementTool = false
    @State private var cloudManagementToolName = ""
    @State private var isSaving = false

    let cloudProviders = ["Azure", "AWS", "Google Cloud", "Other"]

    var body: some View {
        Form {
            Section(header: Text("Cloud Services Assessment")) {
                Toggle("Is your email and file sharing in the cloud?", isOn: $emailAndFileSharingCloud)

                Text("Which cloud service do you use?")
                TextField("", text: $cloudServiceUsed)
                    .textFieldStyle(.roundedBorder)

                Toggle("Do you use infrastructure services in the cloud?", isOn: $usesCloudInfrastructure)

                if usesCloudInfrastructure {
                    Text("Which cloud provider do you use?")
                    Picker("", selection: $selectedCloudProvider) {
                        ForEach(cloudProviders, id: \.self) { provider in
                            Text(provider)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Toggle("Do you use servers?", isOn: $usesServers)
                    if usesServers {
                        Text("How many servers?")
                        TextField("", text: $serverQuantity)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle("Do you use cloud storage?", isOn: $usesStorage)
                    if usesStorage {
                        Text("What is the storage capacity?")
                        TextField("", text: $storageCapacity)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle("Do you use cloud firewalls?", isOn: $usesFirewalls)
                    if usesFirewalls {
                        Text("Please describe your firewall setup:")
                        TextField("", text: $firewallDetails)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle("Do you use other cloud services?", isOn: $usesOther)
                    if usesOther {
                        Text("Please describe the other services:")
                        TextField("", text: $otherDetails)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Toggle("Do you use a cloud management tool such as Nerdio?", isOn: $usesCloudManagementTool)
                if usesCloudManagementTool {
                    Text("Which tool do you use?")
                    TextField("", text: $cloudManagementToolName)
                        .textFieldStyle(.roundedBorder)
                }
            }
            Section {
                Button("Save") {
                    saveCloudServicesAssessment()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSaving ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .scaleEffect(isSaving ? 0.97 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSaving)
            }
        }
        .navigationTitle("Cloud Services Assessment")
        .onAppear {
            loadCloudServicesAssessment()
        }
    }

    func saveCloudServicesAssessment() {
        isSaving = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSaving = false
        }
        let fields: [(String, String?, Bool?)] = [
            ("emailAndFileSharingCloud", nil, emailAndFileSharingCloud),
            ("cloudServiceUsed", cloudServiceUsed, nil),
            ("usesCloudInfrastructure", nil, usesCloudInfrastructure),
            ("selectedCloudProvider", selectedCloudProvider, nil),
            ("usesServers", nil, usesServers),
            ("serverQuantity", serverQuantity, nil),
            ("usesStorage", nil, usesStorage),
            ("storageCapacity", storageCapacity, nil),
            ("usesFirewalls", nil, usesFirewalls),
            ("firewallDetails", firewallDetails, nil),
            ("usesOther", nil, usesOther),
            ("otherDetails", otherDetails, nil),
            ("usesCloudManagementTool", nil, usesCloudManagementTool),
            ("cloudManagementToolName", cloudManagementToolName, nil)
        ]
        coreDataManager.saveAssessmentFields(for: companyName, category: "CloudServices", fields: fields)
    }

    func loadCloudServicesAssessment() {
        let fields = coreDataManager.loadAssessmentFields(for: companyName, category: "CloudServices")

        for field in fields {
            switch field.fieldName {
            case "emailAndFileSharingCloud": emailAndFileSharingCloud = field.valueNumber == 1.0
            case "cloudServiceUsed": cloudServiceUsed = field.valueString ?? ""
            case "usesCloudInfrastructure": usesCloudInfrastructure = field.valueNumber == 1.0
            case "selectedCloudProvider": selectedCloudProvider = field.valueString ?? "Azure"
            case "usesServers": usesServers = field.valueNumber == 1.0
            case "serverQuantity": serverQuantity = field.valueString ?? ""
            case "usesStorage": usesStorage = field.valueNumber == 1.0
            case "storageCapacity": storageCapacity = field.valueString ?? ""
            case "usesFirewalls": usesFirewalls = field.valueNumber == 1.0
            case "firewallDetails": firewallDetails = field.valueString ?? ""
            case "usesOther": usesOther = field.valueNumber == 1.0
            case "otherDetails": otherDetails = field.valueString ?? ""
            case "usesCloudManagementTool": usesCloudManagementTool = field.valueNumber == 1.0
            case "cloudManagementToolName": cloudManagementToolName = field.valueString ?? ""
            default: break
            }
        }
    }
}
