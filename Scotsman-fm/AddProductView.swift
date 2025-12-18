//
//  AddProductView.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//

import SwiftUI

struct AddProductView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ProductViewModel

    @State private var name = ""
    @State private var unitCost = ""
    @State private var unitPrice = ""
    @State private var type = "Hardware"
    @State private var benefits = ""
    @State private var prodDescription = ""
    @State private var units = "Per Device"

    let productTypes = ["Hardware", "Software", "Service", "Labor", "Bundle"]
    let unitTypes = ["Per Device", "Per User", "Per Email User", "Per Site", "Per Hour"]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Service Information")) {
                    TextField("Service Name", text: $name)

                    Picker("Type", selection: $type) {
                        ForEach(productTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    Picker("Units", selection: $units) {
                        ForEach(unitTypes, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
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
            .navigationTitle("Add Service")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    if let cost = Double(unitCost), let sale = Double(unitPrice) {
                        viewModel.addProduct(
                            name: name,
                            unitCost: cost,
                            unitPrice: sale,
                            type: type,
                            benefits: benefits,
                            prodDescription: prodDescription,
                            units: units
                        )
                        dismiss()
                    }
                }
                .disabled(name.isEmpty || unitCost.isEmpty || unitPrice.isEmpty)
            )
        }
    }
}
