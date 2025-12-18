import SwiftUI

struct InfrastructureAssessmentView: View {
    let coreDataManager = CoreDataManager.shared
    let companyName: String
    
    @State private var numberOfOffices = ""
    @State private var hasFirewall = false
    @State private var hasVPN = false
    @State private var vpnType = ""
    @State private var hasMFA = false
    @State private var mfaMethod = ""
    @State private var isp = ""
    @State private var hasSecondaryISP = false
    @State private var secondaryISP = ""
    @State private var hasLoadBalancer = false
    @State private var loadBalancerType = ""
    @State private var happyWithNetwork = false
    @State private var networkIssues = ""
    @State private var hasSecurityCameras = false
    @State private var cameraBrand = ""
    @State private var protectsAssets = false
    @State private var hadBreakIn = false
    @State private var breakInDetails = ""
    @State private var isSaving = false
    
    var body: some View {
        Form {
            Section(header: Text("Infrastructure Assessment")) {
                Text("How many offices do you have?")
                TextField("", text: $numberOfOffices)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                
                Toggle("Does each have a firewall?", isOn: $hasFirewall)
                
                Toggle("Is there a VPN in place?", isOn: $hasVPN)
                if hasVPN {
                    Text("If so, which?")
                    TextField("", text: $vpnType)
                        .textFieldStyle(.roundedBorder)
                }
                
                Toggle("Is it protected by MFA?", isOn: $hasMFA)
                if hasMFA {
                    Text("If so, how?")
                    TextField("", text: $mfaMethod)
                        .textFieldStyle(.roundedBorder)
                }
                
                Text("Who is your ISP?")
                TextField("", text: $isp)
                    .textFieldStyle(.roundedBorder)
                
                Toggle("Do you have a secondary ISP for backup?", isOn: $hasSecondaryISP)
                if hasSecondaryISP {
                    Text("If so, who?")
                    TextField("", text: $secondaryISP)
                        .textFieldStyle(.roundedBorder)
                }
                
                Toggle("Do you have a load balancer in place?", isOn: $hasLoadBalancer)
                if hasLoadBalancer {
                    Text("If so, which?")
                    TextField("", text: $loadBalancerType)
                        .textFieldStyle(.roundedBorder)
                }
                
                Toggle("Are you happy with your network speed and reliability?", isOn: $happyWithNetwork)
                if !happyWithNetwork {
                    Text("If not, why?")
                    TextField("", text: $networkIssues)
                        .textFieldStyle(.roundedBorder)
                }
                
                Toggle("Do you employ cameras for security?", isOn: $hasSecurityCameras)
                if hasSecurityCameras {
                    Text("If so, what brand?")
                    TextField("", text: $cameraBrand)
                        .textFieldStyle(.roundedBorder)
                }
                
                Toggle("Do you protect IT assets by key codes or locks?", isOn: $protectsAssets)
                
                Toggle("Have you experienced a break in?", isOn: $hadBreakIn)
                if hadBreakIn {
                    Text("If so, what happened?")
                    TextField("", text: $breakInDetails)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .navigationTitle("Infrastructure Assessment")

            .onAppear {
                loadInfrastructureAssessment()
            }
        // END of main Section

            Section {
                Button("Save") {
                    saveInfrastructureAssessment()
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
        

    }
    func saveInfrastructureAssessment() {
        isSaving = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSaving = false
        }
        let fields: [(String, String?, Bool?)] = [
            ("numberOfOffices", numberOfOffices, nil),
            ("hasFirewall", nil, hasFirewall),
            ("hasVPN", nil, hasVPN),
            ("vpnType", vpnType, nil),
            ("hasMFA", nil, hasMFA),
            ("mfaMethod", mfaMethod, nil),
            ("isp", isp, nil),
            ("hasSecondaryISP", nil, hasSecondaryISP),
            ("secondaryISP", secondaryISP, nil),
            ("hasLoadBalancer", nil, hasLoadBalancer),
            ("loadBalancerType", loadBalancerType, nil),
            ("happyWithNetwork", nil, happyWithNetwork),
            ("networkIssues", networkIssues, nil),
            ("hasSecurityCameras", nil, hasSecurityCameras),
            ("cameraBrand", cameraBrand, nil),
            ("protectsAssets", nil, protectsAssets),
            ("hadBreakIn", nil, hadBreakIn),
            ("breakInDetails", breakInDetails, nil)
        ]
        coreDataManager.saveAssessmentFields(for: companyName, category: "Infrastructure", fields: fields)
    }
    
    func loadInfrastructureAssessment() {
        let fields = coreDataManager.loadAssessmentFields(for: companyName, category: "Infrastructure")
        
        for field in fields {
            switch field.fieldName {
            case "numberOfOffices": numberOfOffices = field.valueString ?? ""
            case "hasFirewall": hasFirewall = field.valueNumber == 1.0
            case "hasVPN": hasVPN = field.valueNumber == 1.0
            case "vpnType": vpnType = field.valueString ?? ""
            case "hasMFA": hasMFA = field.valueNumber == 1.0
            case "mfaMethod": mfaMethod = field.valueString ?? ""
            case "isp": isp = field.valueString ?? ""
            case "hasSecondaryISP": hasSecondaryISP = field.valueNumber == 1.0
            case "secondaryISP": secondaryISP = field.valueString ?? ""
            case "hasLoadBalancer": hasLoadBalancer = field.valueNumber == 1.0
            case "loadBalancerType": loadBalancerType = field.valueString ?? ""
            case "happyWithNetwork": happyWithNetwork = field.valueNumber == 1.0
            case "networkIssues": networkIssues = field.valueString ?? ""
            case "hasSecurityCameras": hasSecurityCameras = field.valueNumber == 1.0
            case "cameraBrand": cameraBrand = field.valueString ?? ""
            case "protectsAssets": protectsAssets = field.valueNumber == 1.0
            case "hadBreakIn": hadBreakIn = field.valueNumber == 1.0
            case "breakInDetails": breakInDetails = field.valueString ?? ""
            default: break
            }
        }
    }
}
