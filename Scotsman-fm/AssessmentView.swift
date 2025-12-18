import SwiftUI
import CoreData
import PDFKit
import UIKit

struct AssessmentView: View {
    @AppStorage("selectedCompany") private var selectedCompany: String = ""
    @AppStorage("myCompanyName") private var myCompanyName = ""
    @State private var assessmentDate: Date = Date()
    @State private var currentAssessmentID: String = ""

    @EnvironmentObject var coreDataManager: CoreDataManager

    @State private var showCompanySearch = false
    @State private var companySearchText = ""

    @FetchRequest(
        entity: CompanyEntity.entity(),
        sortDescriptors: []
    ) var allCompanies: FetchedResults<CompanyEntity>

    let subjectAreas = [
        ("EndPoints", "desktopcomputer"),
        ("Servers", "server.rack"),
        ("Network", "network"),
        ("PhoneSystem", "phone"),
        ("Email", "envelope"),
        ("Security & Compliance", "lock.shield"),
        ("Directory Services", "person.3"),
        ("Infrastructure", "building.2"),
        ("Cloud Services", "icloud"),
        ("Backup", "externaldrive")
    ]

    let columns = Array(repeating: GridItem(.flexible(minimum: 0)), count: 5)

    var isValidCompanySelected: Bool {
        guard !selectedCompany.isEmpty, !companySearchText.isEmpty else { return false }
        let trimmedSelected = selectedCompany.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedSearch = companySearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCompanies.contains(where: {
            ($0.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedSelected &&
            trimmedSelected == trimmedSearch
        })
    }

    private func updateAssessmentDate() {
        let trimmedName = selectedCompany.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let matchedCompany = allCompanies.first(where: { ($0.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedName }) else {
            assessmentDate = Date()
            currentAssessmentID = ""
            return
        }
        
        let request: NSFetchRequest<AssessmentEntity> = AssessmentEntity.fetchRequest()
        request.predicate = NSPredicate(format: "company == %@", matchedCompany)
        
        if let existing = try? coreDataManager.context.fetch(request).first {
            assessmentDate = existing.date ?? Date()
            currentAssessmentID = existing.id?.uuidString ?? ""
        } else {
            assessmentDate = Date()
            currentAssessmentID = ""
        }
    }

    @ViewBuilder
    func destinationView(for area: String) -> some View {
        switch area {
        case "EndPoints":
            VStack {
                Image(systemName: "desktopcomputer")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .padding(.top)
                EndpointAssessmentView().environmentObject(coreDataManager)
            }
        case "Servers":
            VStack {
                Image(systemName: "server.rack")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .padding(.top)
                ServerAssessmentView().environmentObject(coreDataManager)
            }
        case "Network":
            NetworkAssessmentView().environmentObject(coreDataManager)
        case "PhoneSystem":
            PhoneSystemAssessmentView().environmentObject(coreDataManager)
        case "Email":
            EmailAssessmentView().environmentObject(coreDataManager)
        case "Security & Compliance":
            ProspectSecurityAssessmentView().environmentObject(coreDataManager)
        case "Directory Services":
            DirectoryServicesAssessmentView(companyName: selectedCompany).environmentObject(coreDataManager)
        case "Infrastructure":
            InfrastructureAssessmentView(companyName: selectedCompany).environmentObject(coreDataManager)
        case "Cloud Services":
            CloudServicesAssessmentView(companyName: selectedCompany).environmentObject(coreDataManager)
        case "Backup":
            BackupAssessmentWrapperView(companyName: selectedCompany)
                .environmentObject(coreDataManager)
        default:
            Text("Coming soon for \(area)")
        }
    }


    func exportAssessmentAsPDF() {
        let questionTextMapping: [String: String] = [
            // Email section mappings
            "Email Providers": "Who is your email provider?",
            "Authentication Methods": "How do you authenticate your users?",
            "Email Has MFA": "Do you have MFA on your email service?",
            "Email Has Email Security": "Do you have email security tools in place?",
            "Email Security Brand": "If so, which brand?",
            "Phishing Attempts": "Do you experience phishing attempts?",
            "Backs Up Email": "Do you back up your email accounts?",
            "Email Backup Method": "If so, how?",
            "File Sharing Method": "How does your team do file sharing?",
            "Email Malware": "Have you experienced email malware or account takeover?",
            "Malware Details": "If so, what are the details?",
            "Email Satisfaction": "Are you happy with your email service?",
            "Employee Count": "How many employees do you have?",
            "All Have Email": "Do all employees have an email account?",
            "With Email Count": "If not, how many do?",
            "Email License Types": "What license types (e.g. Business Basic, Premium, etc) do you have?",
            "Windows PCs": "How many Windows PCs do you have?",
            "Windows Managed": "Are these Windows PCs managed?",
            "Macs": "How many Macs do you have?",
            "Mac Managed": "Are these Macs managed?",
            "iPhones": "How many iPhones do you have?",
            "iPhone Managed": "Are these iPhones managed?",
            "iPads": "How many iPads do you have?",
            "iPad Managed": "Are these iPads managed?",
            "Chromebooks": "How many Chromebooks do you have?",
            "Chromebook Managed": "Are these Chromebooks managed?",
            "Android": "How many Android devices do you have?",
            "Android Managed": "Are these Android devices managed?",
            "Runs Windows 11": "Do your PCs all run Windows 11?",
            "Windows Version": "If not, which Windows version do they run?",
            "Device Has MDM": "Are any of your devices managed by an MDM solution?",
            "MDM Provider": "If so, which one?",
            "Device Has AUP": "Does your company have an Acceptable Use Policy?",
            "Allows BYOD": "Do you allow personal devices to access company data or email?",
            "Are Encrypted": "Are your computers encrypted?",
            // Added server-related mappings
            "Physical Servers": "How many physical servers do you have?",
            "Physical Managed": "Are these physical servers managed?",
            "Virtual Servers": "How many virtual servers do you have?",
            "Virtual Managed": "Are these virtual servers managed?",
            "Hypervisors": "How many hypervisors do you have?",
            "Hypervisor Managed": "Are these hypervisors managed?",
            "Server OS": "What operating systems are on your servers?",
            "Hypervisor OS": "What Hypervisor OS do you use?",
            "Server Apps": "What are the main apps or services run on your servers?",
            "Migrate to Cloud": "Do you plan to migrate your servers to the cloud?",
            "Migration Timeframe": "What is your timeframe for migration?",
            "Had Outage": "Have you experienced a major server outage?",
            "Server Recovery Time": "How long did it take to recover from the server outage?",
            // Network-related mappings
            "Has Firewall": "Do you have a Firewall?",
            "Firewall Brand": "What Brand is it?",
            "Firewall Licensed": "Is the software licensed and current?",
            "Has Switches": "Do you have any network switches?",
            "Switch Brand": "If so, what brand?",
            "Has WiFi Network": "Do you have a WiFi Network?",
            "WiFi Brand": "What brand are the Access Points?",
            "Wired or WiFi": "Are most users wired or on WiFi?",
            // Phone System mappings
            "Has VOIP Phone System": "Do you have a VOIP Phone system?",
            "Phone Software": "What software are you using?",
            "Phone Handset Brand": "What brand are the handsets?",
            "Uses Mobile Devices": "Do employees use mobile devices to access the phone system?",
            "Happy with Phone Service": "Are you happy with your phone service?",
            "Phone Service Comments": "If not, why?",
            // Additional Phone System mappings (new field names)
            "Has VOIP": "Do you have a VOIP Phone system?",
            "VOIP Software": "What software are you using?",
            "Handset Brand": "What brand are the handsets?",
            "Uses Mobile Access": "Do employees use mobile devices to access the phone system?",
            "Phone Satisfied": "Are you happy with your phone service?",
            "Phone Dissatisfaction Reason": "If not, why?",
            // Cloud Services mappings (legacy)
            "Cloud Email and File Sharing": "Is your email and file sharing in the cloud?",
            "Cloud Service Used": "Which cloud service do you use?",
            "Cloud Infrastructure Services": "Do you use infrastructure services in the cloud?",
            "Cloud Provider Used": "Which cloud provider do you use?",
            "Cloud Servers": "Do you use servers?",
            "Cloud Storage": "Do you use cloud storage?",
            "Cloud Storage Capacity": "What is the storage capacity?",
            "Cloud Firewalls": "Do you use cloud firewalls?",
            "Other Cloud Services": "Do you use other cloud services?",
            "Other Cloud Services Details": "Please describe the other services:",
            "Cloud Management Tool": "Do you use a cloud management tool such as Nerdio?",
            "Cloud Management Tool Used": "Which tool do you use?",
            // Cloud Services mappings (new fields)
            "emailAndFileSharingCloud": "Is your email and file sharing in the cloud?",
            "cloudServiceUsed": "Which cloud service do you use?",
            "usesCloudInfrastructure": "Do you use infrastructure services in the cloud?",
            "selectedCloudProvider": "Which cloud provider do you use?",
            "usesServers": "Do you use servers?",
            "serverQuantity": "How many servers?",
            "usesStorage": "Do you use cloud storage?",
            "storageCapacity": "What is the storage capacity?",
            "usesFirewalls": "Do you use cloud firewalls?",
            "firewallDetails": "Please describe your firewall setup:",
            "usesOther": "Do you use other cloud services?",
            "otherDetails": "Please describe the other services:",
            "usesCloudManagementTool": "Do you use a cloud management tool such as Nerdio?",
            "cloudManagementToolName": "Which tool do you use?",
            // Backup-related mappings (with correct field names and full questions)
            "backupEndpoints": "Do you backup your EndPoints?",
            "backupEndpointsHow": "If so, how?",
            "backupCloudServices": "Do you backup your cloud services?",
            "backupCloudServicesHow": "If so, how?",
            "backupServers": "Do you backup your servers?",
            "backupServersHow": "If so, how?",
            "hasOffsiteBackup": "Do you have an offsite backup?",
            "offsiteLocation": "If so, where is it stored?",
            "hasCloudBackup": "Do you have a cloud backup of your data?",
            "cloudBackupLocation": "If so, where?",
            "cloudBackupsBootable": "Are your cloud backups bootable?",
            "cloudBootableHow": "If so, how?",
            "canContinueAfterDisaster": "If your building had a fire or disaster, would you be able to continue in business?",
            "hasBackupTest": "Have you done a backup recovery test?",
            "backupTestWhen": "If so, when?",
            "confidentInBackup": "Are you comfortable your backup approach protects you from disaster or cyber-security threats?"
            ,
            // Directory Services mappings
            "Workgroup or Domain": "Are your users in a Workgroup configuration or a Domain?",
            "Authentication Method": "How do they authenticate?",
            "Password Policy": "Do you have a password policy in place?",
            "Encryption Policy": "Do you have an encryption policy in place?",
            "Directory MFA Enforced": "Do you have MFA enforced?",
            "SSO in Place": "Do you have SSO in place?",
            "Which SSO": "Which one?",
            "Last Policy Review": "When was the last time you reviewed IT policies and acceptable use?"
            // Network/Physical Security additional mappings
            ,"numberOfOffices": "How many offices do you have?",
            "hasFirewall": "Does each have a firewall?",
            "hasVPN": "Is there a VPN in place?",
            "vpnType": "If so, which?",
            "hasMFA": "Is it protected by MFA?",
            "mfaMethod": "If so, how?",
            "isp": "Who is your ISP?",
            "hasSecondaryISP": "Do you have a secondary ISP for backup?",
            "secondaryISP": "If so, who?",
            "hasLoadBalancer": "Do you have a load balancer in place?",
            "loadBalancerType": "If so, which?",
            "happyWithNetwork": "Are you happy with your network speed and reliability?",
            "networkIssues": "If not, why?",
            "hasSecurityCameras": "Do you employ cameras for security?",
            "cameraBrand": "If so, what brand?",
            "protectsAssets": "Do you protect IT assets by key codes or locks?",
            "hadBreakIn": "Have you experienced a break in?",
            "breakInDetails": "If so, what happened?",
            // Security & Compliance mappings
            "Experienced Attack": "Have you experienced a cyber-security attack?",
            "Attack Description": "Please describe what happened?",
            "Security Recovery Time": "How long did it take you to recover?",
            "Business Impact": "What was the impact on your business?",
            "Well Secured": "Do you consider your company as well secured?",
            "Has AV": "Do you have an AV solution in place?",
            "AV Solution": "Which one?",
            "Has EDR": "Do you have End Point Detection and Response in place?",
            "EDR Solution": "Which one?",
            "Security Has Email Security": "Do you have an email security solution?",
            "Email Security Solution": "Which one?",
            "Has SIEM": "Do you have a SIEM Solution?",
            "SIEM Solution": "Which one?",
            "Has Training": "Do you have cyber-security training?",
            "Training Solution": "Which one?",
            "Has DNS Protection": "Do you have DNS protection?",
            "DNS Solution": "Which one?",
            "Security Has MFA": "Are your apps and email protected by MFA?",
            "MFA How": "How?",
            "Security MFA Enforced": "Is MFA enforced for all users?",
            "MFA Enforced How": "How?",
            "Security Has MDM": "Do you have a mobile device management solution?",
            "MDM Solution": "Which one?",
            "Allows Personal Mobile": "Do you allow employees to access email or company files on their own mobile devices?",
            "Security Has AUP": "Do you have a published Acceptable Use Policy?",
            "Locked Servers": "Are your server and network equipment secured by a lock?",
            "Has Physical Security": "Do you have any physical security such as camera systems and key codes?",
            "Physical Security Solution": "Which one?",
            "Gets Dark Web Reports": "Do you receive reports on your credentials being traded on the dark web?",
            "Has Password Policy": "Do you have an enforced password policy?",
            "Has Cyber Insurance": "Do you have a cyber-insurance policy in place?",
            "Insurance Renewal": "When is it renewed?",
            "Has Compliance Obligations": "Does your organization have compliance obligations?",
            "Complies With HIPAA": "HIPAA?",
            "Complies With PCI": "PCI?",
            "Complies With FINRA": "FINRA?",
            "Complies With Other": "Other?",
            "Other Compliance Details": "Which?",
            "Is Currently Compliant": "Are you currently compliant?",
            "Interested In Assessment": "Are you interested in a comprehensive security assessment?"
        ]

        let pdfMetaData = [
            kCGPDFContextCreator: "SalesDiver25",
            kCGPDFContextAuthor: "CMIT Solutions",
            kCGPDFContextTitle: "Assessment Report"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 612.0
        let pageHeight = 792.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let categories: [(String, String)] = [
            ("🖥️ Endpoint", "Endpoint"),
            ("🗄️ Servers", "Server"),
            ("🌐 Network", "Network"),
            ("📞 Phone System", "Phone"),
            ("📧 Email", "Email"),
            ("🛡️ Security & Compliance", "Security & Compliance"),
            ("📂 Directory Services", "Directory Services"),
            ("☁️ Infrastructure", "Infrastructure"),
            ("🧩 Cloud Services", "CloudServices"),
            ("💾 Backup", "Backup")
        ]

        let preferredOrder = [
            // Numeric prefixes for locked ordering
            // Endpoints
            "01 - Windows PCs", "02 - Windows Managed",
            "03 - Macs", "04 - Mac Managed",
            "05 - iPhones", "06 - iPhone Managed",
            "07 - iPads", "08 - iPad Managed",
            "09 - Chromebooks", "10 - Chromebook Managed",
            "11 - Android", "12 - Android Managed",
            "13 - Runs Windows 11", "14 - Windows Version",
            "15 - Device Has MDM", "16 - MDM Provider",
            "17 - Device Has AUP", "18 - Allows BYOD", "19 - Are Encrypted",
            // Email (revised order based on screenshots)
            "20 - Email Providers", "21 - Authentication Methods", "22 - Email Has MFA",
            "23 - Email Has Email Security", "24 - Email Security Brand", "25 - Phishing Attempts",
            "26 - Backs Up Email", "27 - Email Backup Method",
            "28 - File Sharing Method", "29 - Email Malware", "30 - Malware Details", "31 - Email Satisfaction",
            "32 - Employee Count", "33 - All Have Email", "34 - With Email Count", "35 - Email License Types",
            // Server
            "36 - Physical Servers", "37 - Physical Managed",
            "38 - Virtual Servers", "39 - Virtual Managed",
            "40 - Hypervisors", "41 - Hypervisor Managed",
            "42 - Server OS", "43 - Hypervisor OS", "44 - Server Apps",
            "45 - Migrate to Cloud", "46 - Migration Timeframe",
            "47 - Had Outage", "48 - Server Recovery Time",
            // Network
            "49 - Has Firewall", "50 - Firewall Brand", "51 - Firewall Licensed",
            "52 - Has Switches", "53 - Switch Brand",
            "54 - Has WiFi Network", "55 - WiFi Brand", "56 - Wired or WiFi",
            // Phone
            "57 - Has VOIP Phone System", "58 - Phone Software", "59 - Phone Handset Brand",
            "60 - Uses Mobile Devices", "61 - Happy with Phone Service", "62 - Phone Service Comments",
            "63 - Has VOIP", "64 - VOIP Software", "65 - Handset Brand", "66 - Uses Mobile Access", "67 - Phone Satisfied", "68 - Phone Dissatisfaction Reason",
            // Cloud Services
            "69 - Cloud Email and File Sharing", "70 - Cloud Service Used", "71 - Cloud Infrastructure Services",
            "72 - Cloud Provider Used", "73 - Cloud Servers", "74 - Cloud Storage", "75 - Cloud Storage Capacity",
            "76 - Cloud Firewalls", "77 - Other Cloud Services", "78 - Other Cloud Services Details",
            "79 - Cloud Management Tool", "80 - Cloud Management Tool Used",
            // Cloud Services (new fields)
            "81 - emailAndFileSharingCloud", "82 - cloudServiceUsed", "83 - usesCloudInfrastructure",
            "84 - selectedCloudProvider", "85 - usesServers", "86 - serverQuantity", "87 - usesStorage", "88 - storageCapacity",
            "89 - usesFirewalls", "90 - firewallDetails", "91 - usesOther", "92 - otherDetails",
            "93 - usesCloudManagementTool", "94 - cloudManagementToolName",
            // Backup
            "95 - backupEndpoints", "96 - backupEndpointsHow",
            "97 - backupCloudServices", "98 - backupCloudServicesHow",
            "99 - backupServers", "100 - backupServersHow",
            "101 - hasOffsiteBackup", "102 - offsiteLocation",
            "103 - hasCloudBackup", "104 - cloudBackupLocation",
            "105 - cloudBackupsBootable", "106 - cloudBootableHow",
            "107 - canContinueAfterDisaster",
            "108 - hasBackupTest", "109 - backupTestWhen",
            "110 - confidentInBackup",
            // Directory Services
            "111 - Workgroup or Domain", "112 - Authentication Method", "113 - Password Policy", "114 - Encryption Policy",
            "115 - Directory MFA Enforced", "116 - SSO in Place", "117 - Which SSO", "118 - Last Policy Review",
            // Network/Physical Security
            "119 - numberOfOffices", "120 - hasFirewall", "121 - hasVPN", "122 - vpnType",
            "123 - hasMFA", "124 - mfaMethod", "125 - isp", "126 - hasSecondaryISP", "127 - secondaryISP",
            "128 - hasLoadBalancer", "129 - loadBalancerType", "130 - happyWithNetwork", "131 - networkIssues",
            "132 - hasSecurityCameras", "133 - cameraBrand", "134 - protectsAssets", "135 - hadBreakIn", "136 - breakInDetails",
            // Security & Compliance (revised order based on screenshots)
            "137 - Experienced Attack", "138 - Attack Description", "139 - Security Recovery Time", "140 - Business Impact",
            "141 - Well Secured", "142 - Has AV", "143 - AV Solution",
            "144 - Has EDR", "145 - EDR Solution",
            "146 - Security Has Email Security", "147 - Email Security Solution",
            "148 - Has SIEM", "149 - SIEM Solution",
            "150 - Has Training", "151 - Training Solution",
            "152 - Has DNS Protection", "153 - DNS Solution",
            "154 - Security Has MFA", "155 - MFA How", "156 - Security MFA Enforced", "157 - MFA Enforced How",
            "158 - Security Has MDM", "159 - MDM Solution",
            "160 - Allows Personal Mobile", "161 - Security Has AUP",
            "162 - Locked Servers", "163 - Has Physical Security", "164 - Physical Security Solution",
            "165 - Gets Dark Web Reports", "166 - Has Password Policy",
            "167 - Has Cyber Insurance", "168 - Insurance Renewal",
            "169 - Has Compliance Obligations", "170 - Complies With HIPAA", "171 - Complies With PCI", "172 - Complies With FINRA",
            "173 - Complies With Other", "174 - Other Compliance Details", "175 - Is Currently Compliant",
            "176 - Interested In Assessment"
        ]

        // Helper to strip numeric prefix
        func stripNumericPrefix(_ s: String) -> String {
            let pattern = #"^\d+\s*-\s*"#
            if let range = s.range(of: pattern, options: .regularExpression) {
                return String(s[range.upperBound...])
            }
            return s
        }

        let data = renderer.pdfData { context in
            // --- FRONT PAGE ---
            context.beginPage()
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let bodyFont = UIFont.systemFont(ofSize: 18)
            let centerStyle = NSMutableParagraphStyle()
            centerStyle.alignment = .center

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .paragraphStyle: centerStyle
            ]

            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .paragraphStyle: centerStyle
            ]

            let companyNameToDisplay = myCompanyName.isEmpty ? "Your Company Name" : myCompanyName
            let frontPageTitle = "IT Assessment for \(selectedCompany)"
            let performedBy = "Performed by \(companyNameToDisplay)"
            let dateString = "Dated: \(formattedDate(assessmentDate))"

            frontPageTitle.draw(in: CGRect(x: 0, y: 200, width: pageWidth, height: 30), withAttributes: titleAttributes)
            performedBy.draw(in: CGRect(x: 0, y: 250, width: pageWidth, height: 30), withAttributes: bodyAttributes)
            dateString.draw(in: CGRect(x: 0, y: 300, width: pageWidth, height: 30), withAttributes: bodyAttributes)

            // --- SECTION PAGES ---
            for (sectionTitle, categoryKey) in categories {
                context.beginPage()

                let titleFont = UIFont.boldSystemFont(ofSize: 20)
                let contentFont = UIFont.systemFont(ofSize: 14)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .left

                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: titleFont,
                    .paragraphStyle: paragraphStyle
                ]

                let contentAttributes: [NSAttributedString.Key: Any] = [
                    .font: contentFont,
                    .paragraphStyle: paragraphStyle
                ]

                let clientTitle = "\(sectionTitle) - \(selectedCompany)"
                clientTitle.draw(at: CGPoint(x: 50, y: 50), withAttributes: titleAttributes)

                // Sort fields using numeric-prefixed preferredOrder, matching by stripping numeric prefix
                let fields = coreDataManager
                    .loadAllAssessmentFields(for: selectedCompany, category: categoryKey)
                    .sorted {
                        let name1 = ($0.fieldName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let name2 = ($1.fieldName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        // Find index in preferredOrder by matching after stripping numeric prefix from preferredOrder
                        let idx1 = preferredOrder.firstIndex(where: { stripNumericPrefix($0) == name1 }) ?? Int.max
                        let idx2 = preferredOrder.firstIndex(where: { stripNumericPrefix($0) == name2 }) ?? Int.max
                        return idx1 < idx2
                    }
                // print("Loaded \(fields.count) fields for \(categoryKey)")

                var yPosition = CGFloat(100)
                let lineSpacing: CGFloat = 8
                let textRectWidth = pageWidth - 100
                let maxY = pageHeight - 50
                for field in fields {
                    let fieldName = (field.fieldName ?? "Unknown").trimmingCharacters(in: .whitespacesAndNewlines)
                    let valueRaw = field.valueString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let fullQuestion: String
                    if let mappedQuestion = questionTextMapping[fieldName] {
                        fullQuestion = mappedQuestion
                    } else {
                        // print("Missing mapping for field: \(fieldName)")
                        fullQuestion = fieldName
                    }
                    let label = "Q: \(fullQuestion)"
                    let answer: String

                    if valueRaw == "true" {
                        answer = "✅ Yes"
                    } else if valueRaw == "false" {
                        answer = "❌ No"
                    } else if valueRaw.isEmpty {
                        answer = "—"
                    } else {
                        answer = valueRaw
                    }

                    let combinedText = "\(label)  \(answer)"
                    let bounding = (combinedText as NSString).boundingRect(with: CGSize(width: textRectWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: contentAttributes, context: nil)
                    (combinedText as NSString).draw(with: CGRect(x: 50, y: yPosition, width: textRectWidth, height: bounding.height), options: .usesLineFragmentOrigin, attributes: contentAttributes, context: nil)
                    yPosition += bounding.height + lineSpacing
                    // Page break if needed
                    if yPosition > maxY {
                        context.beginPage()
                        yPosition = 50
                    }
                }
            }
        }
        // print("PDF generated with \(data.count) bytes.")

        let safeCompany = selectedCompany.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(safeCompany)-Assessment.pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        // print("Saving PDF to:", tempURL.path)
        do {
            try data.write(to: tempURL)
            // print("PDF successfully saved.")
            presentShareSheet(url: tempURL)
        } catch {
            // print("Failed to write PDF: \(error.localizedDescription)")
        }
    }

    func exportAssessmentAsRTF() {
        let title = "IT Assessment for \(selectedCompany)"
        let subtitle = "Performed by \(myCompanyName.isEmpty ? "Your Company Name" : myCompanyName)\nDate: \(formattedDate(assessmentDate))"

        let attr = NSMutableAttributedString()
        let h1 = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 22)]
        let h2 = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)]
        let hSection = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 18)]
        let body = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]

        attr.append(NSAttributedString(string: title + "\n", attributes: h1))
        attr.append(NSAttributedString(string: subtitle + "\n\n", attributes: h2))

        let categories: [(String, String)] = [
            ("🖥️ Endpoint", "Endpoint"),
            ("🗄️ Servers", "Server"),
            ("🌐 Network", "Network"),
            ("📞 Phone System", "Phone"),
            ("📧 Email", "Email"),
            ("🛡️ Security & Compliance", "Security & Compliance"),
            ("📂 Directory Services", "Directory Services"),
            ("☁️ Infrastructure", "Infrastructure"),
            ("🧩 Cloud Services", "CloudServices"),
            ("💾 Backup", "Backup")
        ]

        for (sectionTitle, categoryKey) in categories {
            attr.append(NSAttributedString(string: sectionTitle + "\n", attributes: hSection))
            let fields = coreDataManager
                .loadAllAssessmentFields(for: selectedCompany, category: categoryKey)
            if fields.isEmpty {
                attr.append(NSAttributedString(string: "—\n\n", attributes: body))
            } else {
                for field in fields {
                    let name = (field.fieldName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let raw = field.valueString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let value: String
                    if raw == "true" { value = "Yes" }
                    else if raw == "false" { value = "No" }
                    else if raw.isEmpty { value = "—" }
                    else { value = raw }
                    attr.append(NSAttributedString(string: "• \(name): \(value)\n", attributes: body))
                }
                attr.append(NSAttributedString(string: "\n", attributes: body))
            }
        }

        if let rtf = try? attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            let safeCompany = selectedCompany.replacingOccurrences(of: " ", with: "_")
            let fileName = "\(safeCompany)-Assessment.rtf"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try rtf.write(to: tempURL)
                presentShareSheet(url: tempURL)
            } catch {
                // Failed to write RTF
            }
        }
    }

    func exportAssessmentAsCSV() {
        let safeCompany = selectedCompany.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(safeCompany)-Assessment.csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // CSV header
        var rows: [[String]] = [["Section", "Field", "Value"]]

        let categories: [(String, String)] = [
            ("Endpoint", "Endpoint"),
            ("Servers", "Server"),
            ("Network", "Network"),
            ("Phone System", "Phone"),
            ("Email", "Email"),
            ("Security & Compliance", "Security & Compliance"),
            ("Directory Services", "Directory Services"),
            ("Infrastructure", "Infrastructure"),
            ("Cloud Services", "CloudServices"),
            ("Backup", "Backup")
        ]

        for (sectionTitle, categoryKey) in categories {
            let fields = coreDataManager.loadAllAssessmentFields(for: selectedCompany, category: categoryKey)
            if fields.isEmpty {
                rows.append([sectionTitle, "—", "—"])
            } else {
                for field in fields {
                    let name = (field.fieldName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let raw = field.valueString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let value: String
                    if raw == "true" { value = "Yes" }
                    else if raw == "false" { value = "No" }
                    else if raw.isEmpty { value = "—" }
                    else { value = raw }
                    rows.append([sectionTitle, name, value])
                }
            }
        }

        func escape(_ s: String) -> String {
            if s.contains(",") || s.contains("\n") || s.contains("\"") {
                let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            } else { return s }
        }

        let csv = rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\n") + "\n"
        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            presentShareSheet(url: url)
        } catch {
            // Failed to write CSV
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func presentShareSheet(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            activityVC.popoverPresentationController?.permittedArrowDirections = []

            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }

    var body: some View  {
        NavigationStack {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 20) {
                    Text("Assessment")
                        .font(.largeTitle)
                        .bold()

                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Select Company", text: $companySearchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .onChange(of: companySearchText) {
                                let trimmedSearch = companySearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                let matched = allCompanies.contains { ($0.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedSearch }
                                showCompanySearch = companySearchText.count >= 2 && !matched
                            }

                        if showCompanySearch {
                            let filtered = allCompanies.filter {
                                companySearchText.isEmpty || ($0.name?.localizedCaseInsensitiveContains(companySearchText) ?? false)
                            }.prefix(10)

                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(filtered, id: \.self) { company in
                                    Button(action: {
                                        DispatchQueue.main.async {
                                            showCompanySearch = false
                                            let name = company.name ?? ""
                                            selectedCompany = name
                                            companySearchText = name
                                        }
                                    }) {
                                        Text(company.name ?? "")
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(UIColor.systemBackground))
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 4)
                            .padding(.horizontal, 8)
                        }
                    }

                    DatePicker("Date", selection: $assessmentDate, displayedComponents: .date)
                        .padding(.horizontal, 8)

                    Text("Select Area to Assess:")
                        .font(.headline)
                        .padding(.horizontal, 8)

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(subjectAreas, id: \.0) { area in
                                NavigationLink {
                                    destinationView(for: area.0)
                                } label: {
                                    AssessmentGridItem(area: area, geometry: geometry)
                                }
                                .disabled(!isValidCompanySelected)
                            }
                        }
                        .padding(.bottom, 32)
                        .padding(.horizontal)
                    }
                }
                .padding()
                .onAppear {
                    if isValidCompanySelected {
                        updateAssessmentDate()
                    } else {
                        selectedCompany = ""
                        companySearchText = ""
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                exportAssessmentAsPDF()
                            } label: {
                                Label("Export PDF", systemImage: "doc.richtext")
                            }
                            Button {
                                exportAssessmentAsRTF()
                            } label: {
                                Label("Export Word (RTF)", systemImage: "doc.text")
                            }
                            Button {
                                exportAssessmentAsCSV()
                            } label: {
                                Label("Export Excel (CSV)", systemImage: "tablecells")
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }
}

struct AssessmentGridItem: View {
    let area: (String, String)
    let geometry: GeometryProxy

    var body: some View {
        let safeWidth = max(geometry.size.width, 300)
        let totalSpacing: CGFloat = 20 * 4
        let itemWidth = (safeWidth - totalSpacing - 40) / 5
        let iconSize = itemWidth * 0.4
        let textSize = itemWidth * 0.12

        VStack(spacing: 8) {
            Image(systemName: area.1)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(.blue)

            Text(area.0)
                .font(.system(size: textSize))
                .multilineTextAlignment(.center)
        }
        .frame(width: itemWidth, height: itemWidth)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .padding(4)
    }
}


struct BackupAssessmentWrapperView: View {
    @EnvironmentObject var coreDataManager: CoreDataManager
    let companyName: String

    var body: some View {
        BackupAssessmentView(companyName: companyName)
            .environmentObject(coreDataManager)
    }
}
 
