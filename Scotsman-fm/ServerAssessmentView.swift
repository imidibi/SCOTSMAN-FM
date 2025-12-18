//
//  ServerAssessmentView.swift
//  SalesDiver
//
//  Created by Ian Miller on 4/19/25.
//
import SwiftUI

struct ServerAssessmentView: View {
    @AppStorage("selectedCompany") private var selectedCompany: String = ""
    @EnvironmentObject var coreDataManager: CoreDataManager

    @State private var serverOS = ""
    @State private var hypervisorOS = ""
    @State private var serverApps = ""
    @State private var migrateToCloud = false
    @State private var migrationTimeframe = ""
    @State private var hadOutage = false
    @State private var recoveryTime = ""
    @State private var isSaving = false
    @State private var physicalServerCount = "0"
    @State private var virtualServerCount = "0"
    @State private var hypervisorCount = "0"
    @State private var isPhysicalManaged = false
    @State private var isVirtualManaged = false
    @State private var isHypervisorManaged = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Server Assessment")
                    .font(.largeTitle)
                    .bold()

                GroupBox(label: Label("Server Inventory", systemImage: "server.rack")) {
                    HStack(spacing: 20) {
                        IconCounterView(label: "Physical Servers", icon: "externaldrive", count: $physicalServerCount, isManaged: $isPhysicalManaged)
                        IconCounterView(label: "Virtual Servers", icon: "server.rack", count: $virtualServerCount, isManaged: $isVirtualManaged)
                        IconCounterView(label: "Hypervisors", icon: "cpu", count: $hypervisorCount, isManaged: $isHypervisorManaged)
                    }
                }

                GroupBox(label: Label("Server Configuration", systemImage: "internaldrive")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("What operating systems are on your servers?")
                        TextField("", text: $serverOS).textFieldStyle(.roundedBorder)

                        Text("What Hypervisor OS do you use?")
                        TextField("", text: $hypervisorOS).textFieldStyle(.roundedBorder)

                        Text("What are the main apps or services run on your servers?")
                        TextField("", text: $serverApps).textFieldStyle(.roundedBorder)

                        Toggle("Do you plan to migrate your servers to the cloud?", isOn: $migrateToCloud)

                        Text("Timeframe for migration?")
                        TextField("", text: $migrationTimeframe).textFieldStyle(.roundedBorder)

                        Toggle("Experienced a major server outage?", isOn: $hadOutage)

                        Text("How long did it take to recover?")
                        TextField("", text: $recoveryTime).textFieldStyle(.roundedBorder)
                    }
                    .padding(.top, 5)
                }

                Button("Save") {
                    guard !selectedCompany.isEmpty, !isSaving else { return }
                    isSaving = true
                    let fields: [(String, String?, Bool?)] = [
                        ("Physical Servers", physicalServerCount, nil),
                        ("Physical Managed", nil, isPhysicalManaged),
                        ("Virtual Servers", virtualServerCount, nil),
                        ("Virtual Managed", nil, isVirtualManaged),
                        ("Hypervisors", hypervisorCount, nil),
                        ("Hypervisor Managed", nil, isHypervisorManaged),
                        ("Server OS", serverOS.isEmpty ? nil : serverOS, nil),
                        ("Hypervisor OS", hypervisorOS.isEmpty ? nil : hypervisorOS, nil),
                        ("Server Apps", serverApps.isEmpty ? nil : serverApps, nil),
                        ("Migrate to Cloud", nil, migrateToCloud),
                        ("Migration Timeframe", migrationTimeframe.isEmpty ? nil : migrationTimeframe, nil),
                        ("Had Outage", nil, hadOutage),
                        ("Recovery Time", recoveryTime.isEmpty ? nil : recoveryTime, nil)
                    ]
                    coreDataManager.saveAssessmentFields(for: selectedCompany, category: "Server", fields: fields)
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
            let fields = coreDataManager.loadAllAssessmentFields(for: selectedCompany, category: "Server")
            for field in fields {
                switch field.fieldName {
                case "Server OS": serverOS = field.valueString ?? ""
                case "Hypervisor OS": hypervisorOS = field.valueString ?? ""
                case "Server Apps": serverApps = field.valueString ?? ""
                case "Migrate to Cloud": migrateToCloud = field.valueString == "true"
                case "Migration Timeframe": migrationTimeframe = field.valueString ?? ""
                case "Had Outage": hadOutage = field.valueString == "true"
                case "Recovery Time": recoveryTime = field.valueString ?? ""
                case "Physical Servers": physicalServerCount = field.valueString ?? ""
                case "Physical Managed": isPhysicalManaged = field.valueString == "true"
                case "Virtual Servers": virtualServerCount = field.valueString ?? ""
                case "Virtual Managed": isVirtualManaged = field.valueString == "true"
                case "Hypervisors": hypervisorCount = field.valueString ?? ""
                case "Hypervisor Managed": isHypervisorManaged = field.valueString == "true"
                default: break
                }
            }
        }
    }
}
