import SwiftUI

struct AddOpportunityView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: OpportunityViewModel
    @StateObject private var sheetManager = SheetManager()

    @State private var name: String = ""
    @State private var closeDate: Date = Date()
    @State private var selectedCompany: CompanyWrapper?
    @State private var selectedProduct: ProductWrapper?

    @State private var probability: Int = 0
    @State private var monthlyRevenue: String = ""
    @State private var onetimeRevenue: String = ""
    @State private var estimatedValue: String = ""
    @State private var isEstimatedOverridden = false
    @State private var isDatePickerVisible: Bool = false  // ✅ Toggle for DatePicker visibility
    @State private var status: Int = 1

    @State private var companies: [CompanyWrapper] = []
    @State private var products: [ProductWrapper] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // 🎨 Opportunity Name Input
                        TextField("Opportunity Name", text: $name)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                            .padding(.horizontal)
                            .foregroundColor(.primary)

                        // 🎨 Close Date Picker
                        VStack {
                            Button(action: { isDatePickerVisible.toggle() }) {
                                HStack {
                                    Text("Close Date: \(closeDate.formatted(date: .abbreviated, time: .omitted))")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "calendar")
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                            }
                            .padding(.horizontal)

                            if isDatePickerVisible {
                                VStack {
                                    DatePicker("Select Close Date", selection: $closeDate, displayedComponents: .date)
                                        .datePickerStyle(GraphicalDatePickerStyle())
                                        .padding()
                                    
                                    // ✅ "Done" Button to close picker
                                    Button("Done") {
                                        isDatePickerVisible = false
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                        }

                        // 🎨 Searchable Company Selector
                        SelectionCard(title: "Company", subtitle: selectedCompany?.name ?? "") {
                            sheetManager.showCompanySearch()
                        }

                        // 🎨 Searchable Product Selector
                        SelectionCard(title: "Service", subtitle: selectedProduct?.name ?? "") {
                            sheetManager.showProductSearch()
                        }

                        // 🎨 Financials
                        VStack(spacing: 10) {
                            HStack {
                                Text("Probability:")
                                    .foregroundColor(.primary)
                                Spacer()
                                TextField("0–100", value: $probability, formatter: NumberFormatter())
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                                    .foregroundColor(.primary)
                                Text("%")
                                    .foregroundColor(.primary)
                            }
                            .onChange(of: probability) {
                                if probability < 0 {
                                    probability = 0
                                } else if probability > 100 {
                                    probability = 100
                                }
                            }
                            
                            HStack {
                                Text("Monthly Revenue:")
                                    .foregroundColor(.primary)
                                Spacer()
                                HStack {
                                    Text("$")
                                    TextField("e.g. 1000", text: $monthlyRevenue)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 120)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                                .onChange(of: monthlyRevenue) { updateEstimatedValue() }
                            }

                            HStack {
                                Text("One-Time Revenue:")
                                    .foregroundColor(.primary)
                                Spacer()
                                HStack {
                                    Text("$")
                                    TextField("e.g. 5000", text: $onetimeRevenue)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 120)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                                .onChange(of: onetimeRevenue) { updateEstimatedValue() }
                            }

                            HStack {
                                Text("Estimated Value:")
                                    .foregroundColor(.primary)
                                Spacer()
                                HStack {
                                    Text("$")
                                    TextField("e.g. 17000", text: $estimatedValue)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .foregroundColor(.primary)
                                        .onChange(of: estimatedValue) {
                                            isEstimatedOverridden = true
                                        }
                                }
                                .frame(width: 120)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                            }
                        }
                        .padding(.horizontal)

                        // 🎨 Status Picker
                        VStack(alignment: .leading) {
                            Text("Status:")
                                .foregroundColor(.primary)
                            Picker("Status", selection: $status) {
                                Text("Active").tag(1)
                                Text("Lost").tag(2)
                                Text("Closed").tag(3)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Add Opportunity")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveOpportunity()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundColor(.primary)
                }
            }
            .onAppear(perform: loadCompaniesAndProducts)
            .sheet(item: $sheetManager.activeSheet) { sheet in
                switch sheet {
                case .companySearch:
                    SearchCompanyView(companies: companies) { company in
                        selectedCompany = company
                        sheetManager.dismiss()
                    }
                case .productSearch:
                    SearchProductView(products: products) { product in
                        selectedProduct = product
                        sheetManager.dismiss()
                    }
                }
            }
        }
    }

    // 🎨 Custom Card for Selectable Fields
    private func SelectionCard(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                if !subtitle.isEmpty && subtitle != title {
                    Text(subtitle)
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }

    // ✅ Load Data
    private func loadCompaniesAndProducts() {
        let companyViewModel = CompanyViewModel()
        let productViewModel = ProductViewModel()
        companies = companyViewModel.companies
        products = productViewModel.products
    }

    private func updateEstimatedValue() {
        if isEstimatedOverridden {
            isEstimatedOverridden = false
        }

        let monthlyRaw = monthlyRevenue.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        let oneTimeRaw = onetimeRevenue.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)

        let monthly = Double(monthlyRaw) ?? 0.0
        let oneTime = Double(oneTimeRaw) ?? 0.0

        let calculated = (monthly * 12.0) + oneTime
        estimatedValue = String(format: "%.2f", calculated)
    }

    // ✅ Save Opportunity
    private func saveOpportunity() {
        guard let company = selectedCompany else { return }
        let product = selectedProduct
        let monthly = Double(monthlyRevenue) ?? 0.0
        let onetime = Double(onetimeRevenue) ?? 0.0
        let estimated = Double(estimatedValue) ?? 0.0
        let probabilityVal = Int16(probability)

        viewModel.addOpportunity(
            name: name,
            closeDate: closeDate,
            company: company,
            product: product,
            probability: probabilityVal,
            monthlyRevenue: monthly,
            onetimeRevenue: onetime,
            estimatedValue: estimated,
            status: Int16(status)
        )
    }
}
