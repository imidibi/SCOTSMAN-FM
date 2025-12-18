//
//  SearchProductView.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//
import SwiftUI

struct SearchProductView: View {
    var products: [ProductWrapper]
    var onSelect: (ProductWrapper) -> Void

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss // ✅ Allows manual dismissal

    var filteredProducts: [ProductWrapper] {
        searchText.isEmpty ? products : products.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredProducts) { product in
                Button(action: {
                    onSelect(product)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        dismiss()
                    }
                }) {
                    HStack {
                        Text(product.name)
                        Spacer()
                        Text("$\(product.unitPrice, specifier: "%.2f")")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Search Product")
            .searchable(text: $searchText, prompt: "Search Products")
        }
    }
}
