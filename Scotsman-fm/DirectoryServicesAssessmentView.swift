import SwiftUI

struct DirectoryServicesAssessment {
    var workgroupOrDomain: String = ""
    var authenticationMethod: String = "Active Directory"
    var hasPasswordPolicy: Bool = false
    var hasEncryptionPolicy: Bool = false
    var hasMFA: Bool = false
    var hasSSO: Bool = false
    var whichSSO: String = ""
    var lastPolicyReview: String = ""
}

struct DirectoryServicesAssessmentView: View {
    let companyName: String
    @State private var assessment = DirectoryServicesAssessment()
    @EnvironmentObject var coreDataManager: CoreDataManager
    @State private var isSaving = false
    
    let authenticationOptions = ["Active Directory", "Entra ID", "JumpCloud", "Other"]
    
    private func loadExistingAssessment() {
        let fields = coreDataManager.loadAssessmentFields(for: companyName, category: "Directory Services")
        for field in fields {
            switch field.fieldName {
            case "Workgroup or Domain": assessment.workgroupOrDomain = field.valueString ?? ""
            case "Authentication Method": assessment.authenticationMethod = field.valueString ?? ""
            case "Password Policy": assessment.hasPasswordPolicy = field.valueNumber == 1
            case "Encryption Policy": assessment.hasEncryptionPolicy = field.valueNumber == 1
            case "MFA Enforced": assessment.hasMFA = field.valueNumber == 1
            case "SSO in Place": assessment.hasSSO = field.valueNumber == 1
            case "Which SSO": assessment.whichSSO = field.valueString ?? ""
            case "Last Policy Review": assessment.lastPolicyReview = field.valueString ?? ""
            default: break
            }
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Directory Services Assessment")) {
                Text("Are your users in a Workgroup configuration or a Domain?")
                TextField("", text: $assessment.workgroupOrDomain)
                
                Picker("How do they authenticate?", selection: $assessment.authenticationMethod) {
                    ForEach(authenticationOptions, id: \.self) { option in
                        Text(option)
                    }
                }
                
                Toggle("Do you have a password policy in place?", isOn: $assessment.hasPasswordPolicy)
                Toggle("Do you have an encryption policy in place?", isOn: $assessment.hasEncryptionPolicy)
                Toggle("Do you have MFA enforced?", isOn: $assessment.hasMFA)
                
                Toggle("Do you have SSO in place?", isOn: $assessment.hasSSO)
                
                if assessment.hasSSO {
                    Text("Which one?")
                    TextField("", text: $assessment.whichSSO)
                }
                
                Text("When was the last time you reviewed IT policies and acceptable use?")
                TextField("", text: $assessment.lastPolicyReview)
            }
            
            Section {
                Button("Save") {
                    isSaving = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isSaving = false
                    }

                    coreDataManager.saveAssessmentFields(
                        for: companyName,
                        category: "Directory Services",
                        fields: [
                            ("Workgroup or Domain", assessment.workgroupOrDomain, nil),
                            ("Authentication Method", assessment.authenticationMethod, nil),
                            ("Password Policy", nil, assessment.hasPasswordPolicy),
                            ("Encryption Policy", nil, assessment.hasEncryptionPolicy),
                            ("MFA Enforced", nil, assessment.hasMFA),
                            ("SSO in Place", nil, assessment.hasSSO),
                            ("Which SSO", assessment.whichSSO, nil),
                            ("Last Policy Review", assessment.lastPolicyReview, nil)
                        ]
                    )
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
        .onAppear {
            loadExistingAssessment()
        }
        .navigationTitle("Directory Services")
    }
    
    
    struct DirectoryServicesAssessmentView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                DirectoryServicesAssessmentView(companyName: "Sample Company")
            }
        }
    }
}
