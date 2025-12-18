import SwiftUI
import CoreData

struct SecurityAssessmentView: View {
    @State private var assessmentDate: Date? = nil
    @State private var searchText: String = ""
    @State private var selectedCustomer: String? = nil
    @State private var showClientSelection: Bool = false
    @State private var selections: [String: Bool] = [
        "Security Assessment": false, "Security Awareness": false, "Dark Web Research": false, "Backup": false,
        "Email Protection": false, "Advanced EDR": false, "Mobile Device Security": false, "Physical Security": false,
        "Passwords": false, "SIEM & SOC": false, "Firewall": false, "DNS Protection": false,
        "Multi-Factor Authentication": false, "Computer Updates": false, "Encryption": false, "Cyber Insurance": false
    ]
    @State private var selectedStatus: [String: Status] = [:]
    @State private var showStatusSelection: Bool = false
    @State private var statusToUpdate: String? = nil
    @State private var showErrorMessage: Bool = false

    enum Status: Int16, Codable, CaseIterable {
        case unset = -1
        case protected = 0
        case inProgress = 1
        case atRisk = 2
    
        
        var color: Color {
            switch self {
            case .unset: return Color(.systemGray4)
            case .protected: return .green
            case .inProgress: return .yellow
            case .atRisk: return .red
            }
        }
        
        var description: String {
            switch self {
            case .unset: return "Unset"
            case .protected: return "Protected"
            case .inProgress: return "In Progress"
            case .atRisk: return "At Risk"
            }
        }
    }

    let securityOptions: [(name: String, icon: String)] = [
        ("Security Assessment", "shield.fill"), ("Security Awareness", "person.2.fill"), ("Dark Web Research", "eye.fill"), ("Backup", "arrow.triangle.2.circlepath"),
        ("Email Protection", "envelope.fill"), ("Advanced EDR", "video.fill"), ("Mobile Device Security", "iphone"), ("Physical Security", "hand.raised.fill"),
        ("Passwords", "lock.fill"), ("SIEM & SOC", "exclamationmark.triangle.fill"), ("Firewall", "firewall.fill"), ("DNS Protection", "server.rack"),
        ("Multi-Factor Authentication", "phone.fill"), ("Computer Updates", "icloud.and.arrow.down.fill"), ("Encryption", "sdcard.fill"), ("Cyber Insurance", "creditcard.fill")
    ]

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack {
                    // Show Search Field Only If No Customer Selected
                    if selectedCustomer == nil {
                        searchField
                    } else {
                        Text("\(selectedCustomer ?? "Unknown") - Security Review \(assessmentDate != nil ? assessmentDate!.formatted(date: .numeric, time: .omitted) : "")")
                            .font(.title)
                            .bold()
                            .padding(.bottom, 10)
                    }

                    // Fixed 4x4 Security Assessment Grid
                    ScrollView {
                        securityGrid(geometry: geometry)
                    }
                }
                .onChange(of: selectedCustomer) { oldValue, newValue in
                    guard let companyName = selectedCustomer, !companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
// print("❌ No company selected or empty name. Skipping fetch.")
                        return
                    }
 
// print("📢 Selected Customer Updated: \(companyName)")
 
                    if let companyEntity = CoreDataManager.shared.fetchCompanyByName(name: companyName) {
// print("✅ Company Entity Found: \(companyEntity.name ?? "Unknown")")
 
                        let assessments = CoreDataManager.shared.fetchSecurityAssessments(for: companyEntity)
// print("📊 Security Assessments Fetched: \(assessments.count) for \(companyEntity.name ?? "Unknown")")
 
                        if let latestAssessment = assessments.first {
// print("✅ Latest Assessment Retrieved: \(latestAssessment.assessDate ?? Date())")
                            
                            DispatchQueue.main.async {
                                assessmentDate = latestAssessment.assessDate
                                selectedStatus["Security Assessment"] = SecurityAssessmentView.Status(rawValue: latestAssessment.secAssess) ?? .unset
                                selectedStatus["Security Awareness"] = SecurityAssessmentView.Status(rawValue: latestAssessment.secAware) ?? .unset
                                selectedStatus["Dark Web Research"] = SecurityAssessmentView.Status(rawValue: latestAssessment.darkWeb) ?? .unset
                                selectedStatus["Backup"] = SecurityAssessmentView.Status(rawValue: latestAssessment.backup) ?? .unset
                                selectedStatus["Email Protection"] = SecurityAssessmentView.Status(rawValue: latestAssessment.emailProtect) ?? .unset
                                selectedStatus["Advanced EDR"] = SecurityAssessmentView.Status(rawValue: latestAssessment.advancedEDR) ?? .unset
                                selectedStatus["Mobile Device Security"] = SecurityAssessmentView.Status(rawValue: latestAssessment.mobDevice) ?? .unset
                                selectedStatus["Physical Security"] = SecurityAssessmentView.Status(rawValue: latestAssessment.phySec) ?? .unset
                                selectedStatus["Passwords"] = SecurityAssessmentView.Status(rawValue: latestAssessment.passwords) ?? .unset
                                selectedStatus["SIEM & SOC"] = SecurityAssessmentView.Status(rawValue: latestAssessment.siemSoc) ?? .unset
                                selectedStatus["Firewall"] = SecurityAssessmentView.Status(rawValue: latestAssessment.firewall) ?? .unset
                                selectedStatus["DNS Protection"] = SecurityAssessmentView.Status(rawValue: latestAssessment.dnsProtect) ?? .unset
                                selectedStatus["Multi-Factor Authentication"] = SecurityAssessmentView.Status(rawValue: latestAssessment.mfa) ?? .unset
                                selectedStatus["Computer Updates"] = SecurityAssessmentView.Status(rawValue: latestAssessment.compUpdates) ?? .unset
                                selectedStatus["Encryption"] = SecurityAssessmentView.Status(rawValue: latestAssessment.encryption) ?? .unset
                                selectedStatus["Cyber Insurance"] = SecurityAssessmentView.Status(rawValue: latestAssessment.cyberInsurance) ?? .unset
                            }
                        } else {
                        // print("❌ No assessments found for \(companyEntity.name ?? "Unknown")")
                        DispatchQueue.main.async {
                            for option in securityOptions {
                                selectedStatus[option.name] = .unset
                            }
                            assessmentDate = nil
                        }
                    }
                    } else {
                        // print("❌ No company entity found for \(companyName)")
                    }
                }
            }
            .navigationTitle("Security Review")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard let companyName = selectedCustomer else {
                            showErrorMessage = true
                            return
                        }
                        
                        if let companyEntity = CoreDataManager.shared.fetchCompanyByName(name: companyName) {
                            let assessmentData = securityOptions.map { option in
                                selectedStatus[option.name] ?? .protected
                            }
                            CoreDataManager.shared.saveSecurityAssessment(for: companyEntity, assessmentData: assessmentData)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showClientSelection) {
            ClientSelectionPopover(viewModel: CompanyViewModel(), selectedCustomer: $selectedCustomer, searchText: searchText)
        }
        .onDisappear {
        // print("🔄 Client selection popover dismissed.")
        }
        .alert(isPresented: $showErrorMessage) {
            Alert(title: Text("Error"), message: Text("Please select a company before proceeding."), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: Binding(
            get: { showStatusSelection && statusToUpdate != nil },
            set: { if !$0 { showStatusSelection = false; statusToUpdate = nil } }
        )) {
            if let statusName = statusToUpdate, !statusName.isEmpty {
                StatusSelectionView(
                    selectedStatus: Binding(
                        get: { selectedStatus[statusName] },
                        set: { selectedStatus[statusName] = $0 }
                    ),
                    statusName: statusName
                )
            }
        }
    }
    
    private var searchField: some View {
        HStack {
            TextField("Enter Company Name", text: $searchText)
                .onSubmit {
                    showClientSelection = true
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: { showClientSelection = true }) {
                Image(systemName: "magnifyingglass")
                    .padding()
            }
        }
    }
    
    private func securityGrid(geometry: GeometryProxy) -> some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 4)
        let availableWidth = geometry.size.width
        let availableHeight = geometry.size.height
        let rawCellSize = min(availableWidth, availableHeight) / 4 - 10
        let cellSize = max(rawCellSize, 50) // Ensure cell size is never too small or negative

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(securityOptions, id: \.name) { option in
                SecurityGridItem(option: option, cellSize: cellSize, selectedStatus: $selectedStatus, selectedCustomer: $selectedCustomer, statusToUpdate: $statusToUpdate, showStatusSelection: $showStatusSelection, showErrorMessage: $showErrorMessage)
            }
        }
    }
}

struct SecurityGridItem: View {
    let option: (name: String, icon: String)
    let cellSize: CGFloat
    @Binding var selectedStatus: [String: SecurityAssessmentView.Status]
    @Binding var selectedCustomer: String?
    @Binding var statusToUpdate: String?
    @Binding var showStatusSelection: Bool
    @Binding var showErrorMessage: Bool

    var body: some View {
        let iconSize = cellSize * 0.4
        let textSize = cellSize * 0.12

        VStack {
            HStack {
                Spacer()
                Image(systemName: option.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(.blue)
                Spacer()
            }
            .padding(.top, 10)

            Text(option.name)
                .font(.system(size: textSize))
                .multilineTextAlignment(.center)
        }
        .frame(width: cellSize, height: cellSize)
        .background(selectedStatus[option.name]?.color.opacity(0.3) ?? Color(.systemGray6))
        .cornerRadius(10)
        .onTapGesture {
            if selectedCustomer == nil {
                showErrorMessage = true
            } else {
                statusToUpdate = option.name
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showStatusSelection = true
                }
            }
        }
    }
}

extension SecAssessEntity {
    var secAssessStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.secAssess) ?? .unset }
        set { self.secAssess = newValue.rawValue }
    }
    
    var secAwareStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.secAware) ?? .unset }
        set { self.secAware = newValue.rawValue }
    }

    var darkWebStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.darkWeb) ?? .unset }
        set { self.darkWeb = newValue.rawValue }
    }

    var backupStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.backup) ?? .unset }
        set { self.backup = newValue.rawValue }
    }

    var emailProtectStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.emailProtect) ?? .unset }
        set { self.emailProtect = newValue.rawValue }
    }

    var advancedEDRStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.advancedEDR) ?? .unset }
        set { self.advancedEDR = newValue.rawValue }
    }

    var mobDeviceStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.mobDevice) ?? .unset }
        set { self.mobDevice = newValue.rawValue }
    }

    var phySecStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.phySec) ?? .unset }
        set { self.phySec = newValue.rawValue }
    }

    var passwordsStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.passwords) ?? .unset }
        set { self.passwords = newValue.rawValue }
    }

    var siemSocStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.siemSoc) ?? .unset }
        set { self.siemSoc = newValue.rawValue }
    }

    var firewallStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.firewall) ?? .unset }
        set { self.firewall = newValue.rawValue }
    }

    var dnsProtectStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.dnsProtect) ?? .unset }
        set { self.dnsProtect = newValue.rawValue }
    }

    var mfaStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.mfa) ?? .unset }
        set { self.mfa = newValue.rawValue }
    }

    var compUpdatesStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.compUpdates) ?? .unset }
        set { self.compUpdates = newValue.rawValue }
    }

    var encryptionStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.encryption) ?? .unset }
        set { self.encryption = newValue.rawValue }
    }

    var cyberInsuranceStatus: SecurityAssessmentView.Status {
        get { SecurityAssessmentView.Status(rawValue: self.cyberInsurance) ?? .unset }
        set { self.cyberInsurance = newValue.rawValue }
    }
}

// Status selection view
struct StatusSelectionView: View {
    @Binding var selectedStatus: SecurityAssessmentView.Status?
    var statusName: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var explanationText: String {
        switch statusName {
        case "Security Assessment":
            return "A security assessment helps SMBs identify vulnerabilities in their IT infrastructure before they can be exploited by cybercriminals. By evaluating current security measures, businesses can uncover weaknesses in networks, applications, and policies that could lead to data breaches or compliance violations. Regular assessments ensure that security strategies keep pace with evolving threats, reducing the risk of financial losses and reputational damage. For SMBs with limited IT resources, a security assessment provides a roadmap for prioritizing security investments effectively."
        case "Security Awareness":
            return "Security awareness training educates employees about cyber threats, safe online practices, and how to recognize phishing attempts, reducing the risk of human error and insider threats."
        case "Dark Web Research":
            return "Dark web research helps businesses monitor for leaked or compromised data, enabling them to take proactive measures to protect sensitive information and prevent potential breaches."
        case "Backup":
            return "Regular backups ensure that critical data can be restored in the event of data loss, ransomware attacks, or system failures, minimizing downtime and operational disruption."
        case "Email Protection":
            return "Email protection safeguards against phishing, spam, and malware, ensuring that communication channels remain secure and reducing the risk of cyber attacks."
        case "Advanced EDR":
            return "Advanced Endpoint Detection and Response (EDR) provides real-time monitoring and threat detection on endpoints, enabling rapid response to security incidents and minimizing damage."
        case "Mobile Device Security":
            return "Mobile device security protects smartphones and tablets from cyber threats, ensuring that data accessed on the go remains secure and reducing the risk of unauthorized access."
        case "Physical Security":
            return "Physical security measures protect hardware and sensitive information from unauthorized physical access, theft, or damage, complementing digital security strategies."
        case "Passwords":
            return "Strong password policies and management practices help prevent unauthorized access, reducing the risk of account breaches and data theft."
        case "SIEM & SOC":
            return "Security Information and Event Management (SIEM) and Security Operations Centers (SOC) provide centralized monitoring and analysis of security events, enabling rapid detection and response to threats."
        case "Firewall":
            return "Firewalls act as a barrier between trusted and untrusted networks, filtering traffic and preventing unauthorized access to sensitive systems."
        case "DNS Protection":
            return "DNS protection safeguards against attacks that exploit vulnerabilities in the Domain Name System, preventing malicious redirection and ensuring network reliability."
        case "Multi-Factor Authentication":
            return "Multi-factor authentication adds an extra layer of security by requiring multiple forms of verification, significantly reducing the risk of unauthorized access."
        case "Computer Updates":
            return "Regular computer updates ensure that systems have the latest security patches and features, reducing vulnerabilities and protecting against known threats."
        case "Encryption":
            return "Encryption protects data by converting it into a secure format, ensuring that sensitive information remains confidential even if intercepted."
        case "Cyber Insurance":
            return "Cyber insurance provides financial protection against cyber attacks, helping businesses recover from losses and mitigate the impact of security incidents."
        default:
            return "No explanation available."
        }
    }

    var body: some View {
        VStack {
            Text("\(statusName) Status")
                .font(.headline)
                .padding()

            ForEach(SecurityAssessmentView.Status.allCases.sorted { $0.rawValue < $1.rawValue }, id: \.self) { status in
                Button(action: {
                    selectedStatus = status
                }) {
                    HStack {
                        Text(status.description)
                            .font(selectedStatus == status ? .headline.bold() : .body)
                            .foregroundColor(colorScheme == .dark ? .white : (selectedStatus == status ? .white : .black))
                        Spacer()
                    }
                    .padding()
                    .background(selectedStatus == status ? status.color : Color.clear)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedStatus == status ? Color.clear : Color.gray))
                }
                .padding(.bottom, 10)
            }

            Text("Why is this important?")
                .font(.title)
                .bold()
                .padding(.top)

            Text(explanationText)
                .font(.body)
                .bold()
                .multilineTextAlignment(.center)
                .padding()

            Spacer()

            Button("Done") {
                // Dismiss the modal
                dismiss()
            }
            .padding()
        }
        .padding()
    }
}

// Client selection popover for filtering customers
struct ClientSelectionPopover: View {
    @ObservedObject var viewModel: CompanyViewModel
    @Binding var selectedCustomer: String?
    @Environment(\.dismiss) var dismiss

    var searchText: String

    var filteredCustomers: [CompanyWrapper] {
        viewModel.companies.filter { $0.name.lowercased().hasPrefix(searchText.lowercased()) }
    }

    var body: some View {
        VStack {
            Text("Select Client")
                .font(.headline)
                .padding(.top)

            if filteredCustomers.isEmpty {
                Text("No matching customers")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List {
                    ForEach(filteredCustomers, id: \.id) { customer in
                        Button(action: {
                            DispatchQueue.main.async {
                                selectedCustomer = customer.name
                                // print("✅ Selected Customer Updated: \(selectedCustomer ?? "None")")
                                dismiss()
                            }
                        }) {
                            Text(customer.name)
                                .padding()
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            viewModel.fetchCompanies() // Ensure data is up to date
        }
    }
}

struct SecurityAssessmentView_Previews: PreviewProvider {
    static var previews: some View {
        SecurityAssessmentView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
    }
}
