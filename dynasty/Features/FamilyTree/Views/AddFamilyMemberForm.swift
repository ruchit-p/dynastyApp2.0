import SwiftUI
import ContactsUI
import FirebaseFirestore

struct AddFamilyMemberForm: View {
    @ObservedObject var viewModel: FamilyTreeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var relationType: RelationType = .child // Change FamilyRelationship to RelationType
    let selectedNode: FamilyTreeNode?
    
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var selectedGender = Gender.other
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Member Information")) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                    
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    
                    Picker("Gender", selection: $selectedGender) {
                        Text("Male").tag(Gender.male)
                        Text("Female").tag(Gender.female)
                        Text("Non-Binary").tag(Gender.nonBinary)
                        Text("Other").tag(Gender.other)
                    }
                }
                
                Section {
                    Button(action: addMember) {
                        HStack {
                            Text("Add Member")
                            Spacer()
                        }
                    }
                    .disabled(email.isEmpty || firstName.isEmpty)
                }
            }
            .navigationTitle(getNavigationTitle())
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    private func getNavigationTitle() -> String {
        switch relationType {
        case .parent:
            return "Add Parent"
        case .spouse:
            return "Add Spouse"
        case .child:
            return "Add Child"
        case .sibling:
            return "Add Sibling"
        }
    }
    
    private func addMember() {
        Task {
            let newMember = User(
                id: UUID().uuidString,
                email: email,
                firstName: firstName,
                lastName: lastName,
                dateOfBirth: dateOfBirth,
                gender: selectedGender,
                phoneNumber: nil,
                country: nil,
                photoURL: nil,
                familyTreeID: viewModel.treeId,
                historyBookID: nil,
                parentIds: [],
                childIds: [],
                spouseId: nil,
                siblingIds: [],
                role: .member,
                canAddMembers: false,
                canEdit: false
            )
            
            do {
                switch relationType {
                case .parent:
                    if let selectedNode = selectedNode {
                        try await viewModel.addParent(newMember, to: selectedNode)
                    }
                case .spouse:
                    if let selectedNode = selectedNode {
                        try await viewModel.addSpouse(newMember, to: selectedNode)
                    }
                case .child:
                    if let selectedNode = selectedNode {
                        try await viewModel.addChild(newMember, to: selectedNode)
                    }
                case .sibling:
                    if let selectedNode = selectedNode {
                        try await viewModel.addSibling(newMember, to: selectedNode)
                    }
                }
                
                if viewModel.error == nil {
                    dismiss()
                }
            } catch {
                showingError = true
            }
        }
    }
}

#Preview {
    AddFamilyMemberForm(
        viewModel: FamilyTreeViewModel(treeId: "preview-tree", userId: "preview-user"),
        selectedNode: nil
    )
}
