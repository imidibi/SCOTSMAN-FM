//
//  NetworkAssessmentView.swift
//  SalesDiver
//
//  Created by Ian Miller on 4/19/25.
//
import SwiftUI

struct NetworkAssessmentView: View {
    @AppStorage("selectedCompany") private var selectedCompany: String = ""
    @EnvironmentObject var coreDataManager: CoreDataManager

    @State private var hasFirewall = false
    @State private var firewallBrand = ""
    @State private var firewallLicensed = false
    @State private var hasSwitches = false
    @State private var switchBrand = ""
    @State private var hasWiFi = false
    @State private var wifiBrand = ""
    @State private var wiredOrWifi = ""
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Network Assessment")
                    .font(.largeTitle)
                    .bold()

                GroupBox(label: Label("Network Equipment & Configuration", systemImage: "network")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Do you have a Firewall?", isOn: $hasFirewall)
                        Text("What Brand is it?")
                        TextField("", text: $firewallBrand).textFieldStyle(.roundedBorder)

                        Toggle("Is the software licensed and current?", isOn: $firewallLicensed)

                        Toggle("Do you have any network switches?", isOn: $hasSwitches)
                        Text("If so, what brand?")
                        TextField("", text: $switchBrand).textFieldStyle(.roundedBorder)

                        Toggle("Do you have a WiFi Network?", isOn: $hasWiFi)
                        Text("What brand are the Access Points?")
                        TextField("", text: $wifiBrand).textFieldStyle(.roundedBorder)

                        Text("Are most users wired or on WiFi?")
                        TextField("", text: $wiredOrWifi).textFieldStyle(.roundedBorder)
                    }
                    .padding(.top, 5)
                }

                Button("Save") {
                    guard !selectedCompany.isEmpty, !isSaving else { return }
                    isSaving = true
                    let fields: [(String, String?, Bool?)] = [
                        ("Has Firewall", nil, hasFirewall),
                        ("Firewall Brand", firewallBrand.isEmpty ? nil : firewallBrand, nil),
                        ("Firewall Licensed", nil, firewallLicensed),
                        ("Has Switches", nil, hasSwitches),
                        ("Switch Brand", switchBrand.isEmpty ? nil : switchBrand, nil),
                        ("Has WiFi", nil, hasWiFi),
                        ("WiFi Brand", wifiBrand.isEmpty ? nil : wifiBrand, nil),
                        ("Wired or WiFi", wiredOrWifi.isEmpty ? nil : wiredOrWifi, nil)
                    ]
                    coreDataManager.saveAssessmentFields(for: selectedCompany, category: "Network", fields: fields)
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
            let fields = coreDataManager.loadAllAssessmentFields(for: selectedCompany, category: "Network")
            for field in fields {
                switch field.fieldName {
                case "Has Firewall": hasFirewall = field.valueString == "true"
                case "Firewall Brand": firewallBrand = field.valueString ?? ""
                case "Firewall Licensed": firewallLicensed = field.valueString == "true"
                case "Has Switches": hasSwitches = field.valueString == "true"
                case "Switch Brand": switchBrand = field.valueString ?? ""
                case "Has WiFi": hasWiFi = field.valueString == "true"
                case "WiFi Brand": wifiBrand = field.valueString ?? ""
                case "Wired or WiFi": wiredOrWifi = field.valueString ?? ""
                default: break
                }
            }
        }
    }
}
