//
//  EditOpportunityView.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//

import SwiftUI
import CoreData  // ✅ Added CoreData import

struct EditOpportunityView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: OpportunityViewModel
    var opportunity: OpportunityWrapper

    @State private var name: String = ""
    @State private var closeDate: Date = Date()
    @State private var showingDatePicker = false

    @State private var selectedProduct: ProductWrapper?
    @State private var isSelectingProduct: Bool = false
    @StateObject private var productViewModel = ProductViewModel()

    @State private var probability: Int = 0
    @State private var monthlyRevenue: String = ""
    @State private var onetimeRevenue: String = ""
    @State private var estimatedValue: String = ""
    @State private var isEstimatedOverridden = false

    @State private var status: Int = 1

    var body: some View {
        NavigationStack {
            Form {
                // 🎯 Section: Company Information (Static)
                Section(header: Text("Company")) {
                    Text(opportunity.companyName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                // 🎯 Section: Opportunity Details
                Section(header: Text("Opportunity Details")) {
                    TextField("Opportunity Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(action: { showingDatePicker = true }) {
                        HStack {
                            Text("Close Date")
                            Spacer()
                            Text(closeDate, style: .date)
                                .foregroundColor(.gray)
                        }
                    }

                    if showingDatePicker {
                        VStack {
                            DatePicker("Close Date", selection: $closeDate, displayedComponents: .date)
                                .datePickerStyle(GraphicalDatePickerStyle())
                            Button("Done") {
                                showingDatePicker = false
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    // 🎯 Selectable Product Field
                    Button(action: { isSelectingProduct = true }) {
                        HStack {
                            Text("Service")
                            Spacer()
                            Text(selectedProduct?.name ?? opportunity.productName)
                                .foregroundColor(.gray)
                        }
                    }
                }

                // 🎯 Section: Financial Details
                Section(header: Text("Financial Details")) {
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
                        if probability < 0 { probability = 0 }
                        else if probability > 100 { probability = 100 }
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
                                .onChange(of: estimatedValue) { isEstimatedOverridden = true }
                        }
                        .frame(width: 120)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    }
                    
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

                // 🎯 Delete Button
                Section {
                    Button(role: .destructive, action: deleteOpportunity) {
                        Label("Delete Opportunity", systemImage: "trash")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Opportunity")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveOpportunity()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadExistingData()
            }
            .sheet(isPresented: $isSelectingProduct) {
                ProductSelectionModalView(products: productViewModel.products) { product in  // ✅ Uses correct view
                    selectedProduct = product
                }
            }
        }
    }

    private func loadExistingData() {
        name = opportunity.name
        closeDate = opportunity.closeDate

        probability = opportunity.probability
        monthlyRevenue = String(format: "%.2f", opportunity.monthlyRevenue)
        onetimeRevenue = String(format: "%.2f", opportunity.onetimeRevenue)
        estimatedValue = String(format: "%.2f", opportunity.estimatedValue)

        // ✅ Set initial selected product
        if let product = productViewModel.products.first(where: { $0.name == opportunity.productName }) {
            selectedProduct = product
        }
        
        status = Int(opportunity.status)
    }

    private func saveOpportunity() {
        guard let monthly = Double(monthlyRevenue),
              let onetime = Double(onetimeRevenue),
              let estimated = Double(estimatedValue) else { return }

        // ✅ Fetch the correct ProductEntity from Core Data
        var updatedProduct: NSManagedObject? = opportunity.managedObject.value(forKey: "product") as? NSManagedObject

        if let selectedProductName = selectedProduct?.name {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ProductEntity")
            fetchRequest.predicate = NSPredicate(format: "name == %@", selectedProductName)

            do {
                let matchingProducts = try CoreDataManager.shared.context.fetch(fetchRequest)
                updatedProduct = matchingProducts.first
            } catch {
                print("⚠️ Error fetching selected product: \(error)")
            }
        }

        viewModel.updateOpportunity(
            opportunity: opportunity,
            name: name,
            closeDate: closeDate,
            probability: Int16(probability),
            monthlyRevenue: monthly,
            onetimeRevenue: onetime,
            estimatedValue: estimated,
            status: Int16(status)
        )

        // ✅ Ensure product is updated separately if needed
        if let updatedProduct = updatedProduct {
            opportunity.managedObject.setValue(updatedProduct, forKey: "product")
            CoreDataManager.shared.saveContext()
        }
    }

    private func deleteOpportunity() {
        viewModel.deleteOpportunity(opportunity: opportunity)  // ✅ Correct function call
        dismiss()
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
}
