//
//  EditProductView.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//

import SwiftUI

struct EditProductView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ProductViewModel
    var product: ProductWrapper  // ✅ Now using ProductWrapper instead of ProductEntity

    @State private var name: String
    @State private var unitCost: String
    @State private var unitPrice: String
    @State private var type: String
    @State private var benefits: String
    @State private var prodDescription: String
    @State private var units: String

    init(viewModel: ProductViewModel, product: ProductWrapper) {
        self.viewModel = viewModel
        self.product = product
        _name = State(initialValue: product.name)
        _unitCost = State(initialValue: "\(product.unitCost)")
        _unitPrice = State(initialValue: "\(product.unitPrice)")
        _type = State(initialValue: product.type)
        _benefits = State(initialValue: product.benefits)
        _prodDescription = State(initialValue: product.prodDescription)
        _units = State(initialValue: product.units)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Service Information")) {
                    TextField("Service Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(["Hardware", "Software", "Service", "Labor", "Bundle"], id: \.self) { Text($0) }
                    }
                    Picker("Units", selection: $units) {
                        ForEach(["Per Device", "Per User", "Per Email User", "Per Site", "Per Hour"], id: \.self) { Text($0) }
                    }
                }

                Section(header: Text("Pricing")) {
                    HStack {
                        Text("Unit Cost: $")
                        TextField("0.00", text: $unitCost)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        Text("Unit Price: $")
                        TextField("0.00", text: $unitPrice)
                            .keyboardType(.decimalPad)
                    }
                }

                Section(header: Text("Description")) {
                    TextEditor(text: $prodDescription)
                        .frame(height: 100)
                }

                Section(header: Text("Benefits")) {
                    TextEditor(text: $benefits)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Edit Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let convertedunitCost = Double(unitCost) ?? 0.0
                        let convertedunitPrice = Double(unitPrice) ?? 0.0

                        viewModel.updateProduct(
                            product: product,
                            name: name,
                            unitCost: convertedunitCost,
                            unitPrice: convertedunitPrice,
                            type: type,
                            benefits: benefits,
                            prodDescription: prodDescription,
                            units: units
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}
