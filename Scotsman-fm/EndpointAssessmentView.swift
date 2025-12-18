//
//  EndpointAssessmentView.swift
//  SalesDiver
//
//  Created by Ian Miller on 4/19/25.
//

import SwiftUI

struct EndpointAssessmentView: View {
    @AppStorage("selectedCompany") private var selectedCompany: String = ""
    @EnvironmentObject var coreDataManager: CoreDataManager

    @State private var windowsCount = "0"
    @State private var macCount = "0"
    @State private var chromebookCount = "0"
    @State private var iphoneCount = "0"
    @State private var ipadCount = "0"
    @State private var androidCount = "0"
    @State private var isWindowsManaged = false
    @State private var isMacManaged = false
    @State private var isChromebookManaged = false
    @State private var isIphoneManaged = false
    @State private var isIpadManaged = false
    @State private var isAndroidManaged = false
    @State private var runsWindows11 = false
    @State private var windowsVersion = ""
    @State private var hasMDM = false
    @State private var mdmProvider = ""
    @State private var hasAUP = false
    @State private var allowsBYOD = false
    @State private var areEncrypted = false
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("Endpoint Assessment")
                    .font(.largeTitle)
                    .bold()
                GroupBox(label: Label("Device Inventory", systemImage: "desktopcomputer")) {
                    VStack(spacing: 20) {
                        HStack(spacing: 20) {
                            IconCounterView(label: "Windows PCs", icon: "desktopcomputer", count: $windowsCount, isManaged: $isWindowsManaged)
                            IconCounterView(label: "Macs", icon: "laptopcomputer", count: $macCount, isManaged: $isMacManaged)
                            IconCounterView(label: "iPhones", icon: "iphone", count: $iphoneCount, isManaged: $isIphoneManaged)
                        }
                        HStack(spacing: 20) {
                            IconCounterView(label: "iPads", icon: "ipad", count: $ipadCount, isManaged: $isIpadManaged)
                            IconCounterView(label: "Chromebooks", icon: "display", count: $chromebookCount, isManaged: $isChromebookManaged)
                            IconCounterView(label: "Android", icon: "iphone.gen3", count: $androidCount, isManaged: $isAndroidManaged)
                        }
                    }
                }

                GroupBox(label: Label("Device Configuration", systemImage: "gearshape.2")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Toggle("Do your PCs all run Windows 11?", isOn: $runsWindows11)

                        Text("If not, which Windows version do they run?")
                        TextField("", text: $windowsVersion)
                            .textFieldStyle(.roundedBorder)

                        Toggle("Are any of your devices managed by an MDM solution?", isOn: $hasMDM)

                        Text("If so, which one?")
                        TextField("", text: $mdmProvider)
                            .textFieldStyle(.roundedBorder)

                        Toggle("Does your company have an Acceptable Use Policy?", isOn: $hasAUP)
                        Toggle("Do you allow personal devices to access company data or email?", isOn: $allowsBYOD)
                        Toggle("Are your computers encrypted?", isOn: $areEncrypted)
                    }
                    .padding(.top, 5)
                }

                Button("Save") {
                    guard !selectedCompany.isEmpty, !isSaving else { return }
                    isSaving = true
                    let fields: [(String, String?, Bool?)] = [
                        ("Windows PCs", windowsCount, nil),
                        ("Windows Managed", nil, isWindowsManaged),
                        ("Macs", macCount, nil),
                        ("Mac Managed", nil, isMacManaged),
                        ("iPhones", iphoneCount, nil),
                        ("iPhone Managed", nil, isIphoneManaged),
                        ("iPads", ipadCount, nil),
                        ("iPad Managed", nil, isIpadManaged),
                        ("Chromebooks", chromebookCount, nil),
                        ("Chromebook Managed", nil, isChromebookManaged),
                        ("Android", androidCount, nil),
                        ("Android Managed", nil, isAndroidManaged),
                        ("Runs Windows 11", nil, runsWindows11),
                        ("Windows Version", windowsVersion.isEmpty ? nil : windowsVersion, nil),
                        ("Has MDM", nil, hasMDM),
                        ("MDM Provider", mdmProvider.isEmpty ? nil : mdmProvider, nil),
                        ("Has AUP", nil, hasAUP),
                        ("Allows BYOD", nil, allowsBYOD),
                        ("Are Encrypted", nil, areEncrypted)
                    ]
                    coreDataManager.saveAssessmentFields(for: selectedCompany, category: "Endpoint", fields: fields)
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
            let fields = coreDataManager.loadAllAssessmentFields(for: selectedCompany, category: "Endpoint")
            for field in fields {
                switch field.fieldName {
                case "Runs Windows 11": runsWindows11 = field.valueString == "true"
                case "Windows Version": windowsVersion = field.valueString ?? ""
                case "Has MDM": hasMDM = field.valueString == "true"
                case "MDM Provider": mdmProvider = field.valueString ?? ""
                case "Has AUP": hasAUP = field.valueString == "true"
                case "Allows BYOD": allowsBYOD = field.valueString == "true"
                case "Are Encrypted": areEncrypted = field.valueString == "true"
                case "Windows PCs": windowsCount = field.valueString ?? ""
                case "Windows Managed": isWindowsManaged = field.valueString == "true"
                case "Macs": macCount = field.valueString ?? ""
                case "Mac Managed": isMacManaged = field.valueString == "true"
                case "iPhones": iphoneCount = field.valueString ?? ""
                case "iPhone Managed": isIphoneManaged = field.valueString == "true"
                case "iPads": ipadCount = field.valueString ?? ""
                case "iPad Managed": isIpadManaged = field.valueString == "true"
                case "Chromebooks": chromebookCount = field.valueString ?? ""
                case "Chromebook Managed": isChromebookManaged = field.valueString == "true"
                case "Android": androidCount = field.valueString ?? ""
                case "Android Managed": isAndroidManaged = field.valueString == "true"
                default: break
                }
            }
        }
    }
}
