//
//  ProductDataView.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//
import SwiftUI
import CoreData

struct ProductDataView: View {
    @StateObject private var viewModel = ProductViewModel()
    @State private var isShowingAddSheet = false
    @State private var selectedProduct: ProductWrapper?

    var body: some View {
        NavigationStack {
            VStack {
                // 🔍 Search Bar
                HStack {
                    TextField("Search products...", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .onChange(of: viewModel.searchText) {
                            viewModel.fetchProducts()
                        }

                    if !viewModel.searchText.isEmpty {
                        Button(action: {
                            viewModel.searchText = ""
                            viewModel.fetchProducts()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing, 8)
                    }
                }
                // 🔀 Sorting Options
                Picker("Sort by", selection: $viewModel.sortOption) {
                    ForEach(ProductSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: viewModel.sortOption) {
                    viewModel.fetchProducts()
                }

              List {
                    ForEach(viewModel.products) { product in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name)
                                .font(.headline)

                            Text("Type: \(product.type)")
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            Text("Units: \(product.units)")
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            Text("Cost: $\(product.unitCost, specifier: "%.2f") | Sale: $\(product.unitPrice, specifier: "%.2f")")
                                .font(.subheadline)
                                .foregroundColor(.gray)

                            Text("Description: \(product.prodDescription)")
                                .font(.footnote)
                                .foregroundColor(.secondary)

                            Text("Benefits: \(product.benefits)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .onTapGesture {
                            selectedProduct = product
                        }
                    }
                    .onDelete(perform: deleteProduct)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Services")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isShowingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                }
            }
            .sheet(item: $selectedProduct) { product in
                EditProductView(viewModel: viewModel, product: product)
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddProductView(viewModel: viewModel)
            }
        }
    }

    private func deleteProduct(at offsets: IndexSet) {
        for index in offsets {
            let product = viewModel.products[index]
            viewModel.deleteProduct(product: product)
        }
        viewModel.products.remove(atOffsets: offsets)
    }
}
