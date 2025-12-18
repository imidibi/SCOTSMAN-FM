//
//  BackupAssessmentView.swift
//  SalesDiver
//
//  Created by Ian Miller on 4/20/25.
import SwiftUI

struct BackupAssessmentView: View {
    let coreDataManager = CoreDataManager.shared
    let companyName: String
    @State private var currentAssessment: AssessmentEntity?
    @State private var backupEndpoints = false
    @State private var backupEndpointsHow = ""
    @State private var backupCloudServices = false
    @State private var backupCloudServicesHow = ""
    @State private var backupServers = false
    @State private var backupServersHow = ""
    @State private var hasOffsiteBackup = false
    @State private var offsiteLocation = ""
    @State private var hasCloudBackup = false
    @State private var cloudBackupLocation = ""
    @State private var cloudBackupsBootable = false
    @State private var cloudBootableHow = ""
    @State private var canContinueAfterDisaster = false
    @State private var hasBackupTest = false
    @State private var backupTestWhen = ""
    @State private var confidentInBackup = false
    @State private var isSaving = false

    var body: some View {
        Form {
            Section(header: Text("Backup Assessment")) {
                Toggle("Do you backup your EndPoints?", isOn: $backupEndpoints)
                if backupEndpoints {
                    Text("If so, how?")
                    TextField("", text: $backupEndpointsHow)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Do you backup your cloud services?", isOn: $backupCloudServices)
                if backupCloudServices {
                    Text("If so, how?")
                    TextField("", text: $backupCloudServicesHow)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Do you backup your servers?", isOn: $backupServers)
                if backupServers {
                    Text("If so, how?")
                    TextField("", text: $backupServersHow)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Do you have an offsite backup?", isOn: $hasOffsiteBackup)
                if hasOffsiteBackup {
                    Text("If so, where is it stored?")
                    TextField("", text: $offsiteLocation)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Do you have a cloud backup of your data?", isOn: $hasCloudBackup)
                if hasCloudBackup {
                    Text("If so, where?")
                    TextField("", text: $cloudBackupLocation)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Are your cloud backups bootable?", isOn: $cloudBackupsBootable)
                if cloudBackupsBootable {
                    Text("If so, how?")
                    TextField("", text: $cloudBootableHow)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("If your building had a fire or disaster, would you be able to continue in business?", isOn: $canContinueAfterDisaster)

                Toggle("Have you done a backup recovery test?", isOn: $hasBackupTest)
                if hasBackupTest {
                    Text("If so, when?")
                    TextField("", text: $backupTestWhen)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Are you comfortable your backup approach protects you from disaster or cyber-security threats?", isOn: $confidentInBackup)
            }
            Section {
                Button("Save") {
                    saveBackupAssessment()
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
        .navigationTitle("Backup Assessment")
        .onAppear {
            // print("Loading Backup assessment for company: \(companyName)")
            loadBackupAssessment()
        }
        .onDisappear {
            // print("Auto-saving Backup assessment for company: \(companyName)")
            saveBackupAssessment()
        }
    }

    func saveBackupAssessment() {
        isSaving = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSaving = false
        }
        // print("💾 Calling saveBackupAssessment for \(companyName)")
        let fields: [(String, String?, Bool?)] = [
            ("backupEndpoints", nil, backupEndpoints),
            ("backupEndpointsHow", backupEndpointsHow.isEmpty ? nil : backupEndpointsHow, nil),
            ("backupCloudServices", nil, backupCloudServices),
            ("backupCloudServicesHow", backupCloudServicesHow.isEmpty ? nil : backupCloudServicesHow, nil),
            ("backupServers", nil, backupServers),
            ("backupServersHow", backupServersHow.isEmpty ? nil : backupServersHow, nil),
            ("hasOffsiteBackup", nil, hasOffsiteBackup),
            ("offsiteLocation", offsiteLocation.isEmpty ? nil : offsiteLocation, nil),
            ("hasCloudBackup", nil, hasCloudBackup),
            ("cloudBackupLocation", cloudBackupLocation.isEmpty ? nil : cloudBackupLocation, nil),
            ("cloudBackupsBootable", nil, cloudBackupsBootable),
            ("cloudBootableHow", cloudBootableHow.isEmpty ? nil : cloudBootableHow, nil),
            ("canContinueAfterDisaster", nil, canContinueAfterDisaster),
            ("hasBackupTest", nil, hasBackupTest),
            ("backupTestWhen", backupTestWhen.isEmpty ? nil : backupTestWhen, nil),
            ("confidentInBackup", nil, confidentInBackup)
        ]
        coreDataManager.saveAssessmentFields(for: companyName, category: "Backup", fields: fields)
    }

    func loadBackupAssessment() {
        currentAssessment = coreDataManager.getOrCreateAssessment(for: companyName)
        let fields = coreDataManager.loadAssessmentFields(for: companyName, category: "Backup")
        // print("Loaded fields: \(fields)")

        for field in fields {
            switch field.fieldName {
            case "backupEndpoints": backupEndpoints = field.valueNumber == 1.0
            case "backupEndpointsHow": backupEndpointsHow = field.valueString ?? ""
            case "backupCloudServices": backupCloudServices = field.valueNumber == 1.0
            case "backupCloudServicesHow": backupCloudServicesHow = field.valueString ?? ""
            case "backupServers": backupServers = field.valueNumber == 1.0
            case "backupServersHow": backupServersHow = field.valueString ?? ""
            case "hasOffsiteBackup": hasOffsiteBackup = field.valueNumber == 1.0
            case "offsiteLocation": offsiteLocation = field.valueString ?? ""
            case "hasCloudBackup": hasCloudBackup = field.valueNumber == 1.0
            case "cloudBackupLocation": cloudBackupLocation = field.valueString ?? ""
            case "cloudBackupsBootable": cloudBackupsBootable = field.valueNumber == 1.0
            case "cloudBootableHow": cloudBootableHow = field.valueString ?? ""
            case "canContinueAfterDisaster": canContinueAfterDisaster = field.valueNumber == 1.0
            case "hasBackupTest": hasBackupTest = field.valueNumber == 1.0
            case "backupTestWhen": backupTestWhen = field.valueString ?? ""
            case "confidentInBackup": confidentInBackup = field.valueNumber == 1.0
            default: break
            }
        }
    }
}
