//
//  AddCompanyView.swift.swift
//  iPadtester
//
//  Created by Ian Miller on 2/15/25.
//
import SwiftUI

struct AddCompanyView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: CompanyViewModel

    @State private var name = ""
    @State private var address = ""
    @State private var address2 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var mainContact = ""
    @State private var webAddress = ""
    @State private var companyType = 1

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Company Information")) {
                    TextField("Company Name", text: $name)
                    TextField("Address", text: $address)
                    TextField("Address2", text: $address2)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("Zip Code", text: $zipCode)
                    TextField("Main Contact", text: $mainContact)
                    TextField("Web Address", text: $webAddress)
                    Picker("Company Type", selection: $companyType) {
                        Text("Customer").tag(1)
                        Text("Lead").tag(2)
                        Text("Prospect").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Company")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.addCompany(name: name, address: address, address2: address2, city: city, state: state, zipCode: zipCode, mainContact: mainContact, webAddress: webAddress, companyType: companyType)
                        dismiss()
                    }
                    .disabled(name.isEmpty /*|| address.isEmpty || address2.isEmpty || city.isEmpty || state.isEmpty || zipCode.isEmpty || mainContact.isEmpty*/)
                }
            }
        }
    }
}
