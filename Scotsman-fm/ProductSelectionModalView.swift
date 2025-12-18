//
//  ProductSelectionModalView.swift
//  SalesDiver
//
//  Created by Ian Miller on 2/22/25.
//
//
//  ProductSelectionModalView.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//

import SwiftUI

struct ProductSelectionModalView: View {
    let products: [ProductWrapper]
    var onSelect: (ProductWrapper) -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List(products) { product in
                Button(action: {
                    onSelect(product)
                    dismiss()
                }) {
                    HStack {
                        Text(product.name)
                            .font(.headline)
                        Spacer()
                        Text("$\(product.unitPrice, specifier: "%.2f")")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Select Product")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
