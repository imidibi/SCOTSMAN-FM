import SwiftUI
import CoreData

struct ContactsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: ContactsEntity.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ContactsEntity.firstName, ascending: true),
            NSSortDescriptor(keyPath: \ContactsEntity.lastName, ascending: true)
        ]
    ) private var contacts: FetchedResults<ContactsEntity>

    @State private var searchText = ""
    @State private var showingAddContact = false
    @State private var selectedContact: ContactsEntity?
    @State private var sortOption: SortOption = .firstName

    enum SortOption {
        case firstName, lastName, companyName
    }

    var filteredContacts: [ContactsEntity] {
        contacts.filter { contact in
            searchText.isEmpty ||
            contact.firstName?.localizedCaseInsensitiveContains(searchText) == true ||
            contact.lastName?.localizedCaseInsensitiveContains(searchText) == true ||
            contact.emailAddress?.localizedCaseInsensitiveContains(searchText) == true ||
            contact.phone?.localizedCaseInsensitiveContains(searchText) == true ||
            contact.company?.name?.localizedCaseInsensitiveContains(searchText) == true
        }
        .sorted(by: { lhs, rhs in
            switch sortOption {
                case .firstName:
                    return (lhs.firstName ?? "") < (rhs.firstName ?? "")
                case .lastName:
                    return (lhs.lastName ?? "") < (rhs.lastName ?? "")
                case .companyName:
                    return (lhs.company?.name ?? "") < (rhs.company?.name ?? "")
            }
        })
    }

    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(text: $searchText)

                Picker("Sort by", selection: $sortOption) {
                    Text("First Name").tag(SortOption.firstName)
                    Text("Last Name").tag(SortOption.lastName)
                    Text("Company Name").tag(SortOption.companyName)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                List {
                    ForEach(filteredContacts, id: \.self) { contact in
                        HStack(alignment: .top) {
                            Button(action: {
                                selectedContact = contact
                            }) {
                                VStack(alignment: .leading) {
                                    Text("\(contact.firstName ?? "Unknown") \(contact.lastName ?? "")")
                                        .font(.headline)

                                    if let companyName = contact.company?.name, !companyName.isEmpty {
                                        Text("Company: \(companyName)")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }

                                    if let email = contact.emailAddress, !email.isEmpty {
                                        Text("Email: \(email)")
                                    }

                                    if let phone = contact.phone, !phone.isEmpty {
                                        Text("Phone: \(phone)")
                                    }

                                    if let title = contact.title, !title.isEmpty {
                                        Text("Title: \(title)")
                                    }
                                }
                                .padding(.vertical, 5)
                                .foregroundColor(.primary)
                            }
                            .buttonStyle(PlainButtonStyle())

                            if let email = contact.emailAddress, !email.isEmpty, let emailURL = URL(string: "mailto:\(email)") {
                                Spacer()
                                Link(destination: emailURL) {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteContact)
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(action: {
                showingAddContact = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
            })
            .sheet(isPresented: $showingAddContact) {
                AddContactView()
            }
            .sheet(item: $selectedContact) { contact in
                EditContactView(contact: contact)
            }
        }
    }

    private func deleteContact(at offsets: IndexSet) {
        for index in offsets {
            let contact = filteredContacts[index]
            viewContext.delete(contact)
        }
        do {
            try viewContext.save()
        } catch {
            // print("Failed to delete contact: \(error.localizedDescription)")
        }
    }
}

struct CompanyPickerView: View {
    @Binding var selectedCompany: CompanyEntity?
    @Environment(\.presentationMode) var presentationMode
    var companies: FetchedResults<CompanyEntity>

    var body: some View {
        NavigationStack {
            List(companies, id: \.self) { company in
                Button(action: {
                    selectedCompany = company
                    presentationMode.wrappedValue.dismiss() // Auto-close on selection
                }) {
                    Text(company.name ?? "Unknown")
                        .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Company")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var body: some View {
        TextField("Search...", text: $text)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
    }
}

struct AddContactView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var viewContext
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var title: String = ""
    @State private var emailAddress: String = ""
    @State private var phone: String = ""
    @State private var address1: String = ""
    @State private var address2: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var postalCode: String = ""
    @State private var selectedCompany: CompanyEntity?
    @State private var showingCompanyPicker = false
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    @FetchRequest(entity: CompanyEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \CompanyEntity.name, ascending: true)])
    private var companies: FetchedResults<CompanyEntity>
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(action: {
                        showingCompanyPicker.toggle()
                    }) {
                        HStack {
                            Text("Select Company")
                                .foregroundColor(.blue)
                            Spacer()
                            Text(selectedCompany?.name ?? "None")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .sheet(isPresented: $showingCompanyPicker) {
                    CompanyPickerView(selectedCompany: $selectedCompany, companies: companies)
                }
                
                Section(header: Text("Contact Details")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Title", text: $title)
                    TextField("Email", text: $emailAddress)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                Section(header: Text("Address")) {
                    TextField("Address 1", text: $address1)
                    TextField("Address 2", text: $address2)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("Zip Code", text: $postalCode)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                guard selectedCompany != nil else {
                    alertMessage = "Please select a company before saving the contact."
                    showAlert = true
                    return
                }
                addContact()
            })
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Missing Company"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func addContact() {
        let newContact = ContactsEntity(context: viewContext)
        newContact.firstName = firstName
        newContact.lastName = lastName
        newContact.title = title
        newContact.emailAddress = emailAddress
        newContact.phone = phone
        newContact.address1 = address1
        newContact.address2 = address2
        newContact.city = city
        newContact.state = state
        newContact.postalCode = postalCode
        newContact.company = selectedCompany
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            // print("Error saving contact: \(error.localizedDescription)")
        }
    }
}

struct EditContactView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var viewContext
    @State private var firstName: String
    @State private var lastName: String
    @State private var title: String
    @State private var emailAddress: String
    @State private var phone: String
    @State private var address1: String
    @State private var address2: String
    @State private var city: String
    @State private var state: String
    @State private var postalCode: String
    @State private var selectedCompany: CompanyEntity?
    @State private var showingCompanyPicker = false
    var contact: ContactsEntity
    
    @FetchRequest(entity: CompanyEntity.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \CompanyEntity.name, ascending: true)])
    private var companies: FetchedResults<CompanyEntity>
    
    init(contact: ContactsEntity) {
        self.contact = contact
        _firstName = State(initialValue: contact.firstName ?? "")
        _lastName = State(initialValue: contact.lastName ?? "")
        _title = State(initialValue: contact.title ?? "")
        _emailAddress = State(initialValue: contact.emailAddress ?? "")
        _phone = State(initialValue: contact.phone ?? "")
        _address1 = State(initialValue: contact.address1 ?? "")
        _address2 = State(initialValue: contact.address2 ?? "")
        _city = State(initialValue: contact.city ?? "")
        _state = State(initialValue: contact.state ?? "")
        _postalCode = State(initialValue: contact.postalCode ?? "")
        _selectedCompany = State(initialValue: contact.company)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(action: {
                        showingCompanyPicker.toggle()
                    }) {
                        HStack {
                            Text("Select Company")
                                .foregroundColor(.blue)
                            Spacer()
                            Text(selectedCompany?.name ?? "None")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .sheet(isPresented: $showingCompanyPicker) {
                    CompanyPickerView(selectedCompany: $selectedCompany, companies: companies)
                }
                
                Section(header: Text("Contact Details")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Title", text: $title)
                    TextField("Email", text: $emailAddress)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                Section(header: Text("Address")) {
                    TextField("Address 1", text: $address1)
                    TextField("Address 2", text: $address2)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("Zip Code", text: $postalCode)
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                updateContact()
            })
        }
    }
    
    private func updateContact() {
        contact.firstName = firstName
        contact.lastName = lastName
        contact.title = title
        contact.emailAddress = emailAddress
        contact.phone = phone
        contact.address1 = address1
        contact.address2 = address2
        contact.city = city
        contact.state = state
        contact.postalCode = postalCode
        contact.company = selectedCompany
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            // print("Error updating contact: \(error.localizedDescription)")
        }
    }
}
