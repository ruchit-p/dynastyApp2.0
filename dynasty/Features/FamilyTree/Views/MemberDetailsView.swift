import SwiftUI
import FirebaseAuth

struct MemberDetailsView: View {
    let node: FamilyTreeNode
    let viewModel: FamilyTreeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var isEditing = false
    @State private var firstName: String
    @State private var lastName: String
    @State private var dateOfBirth: Date
    @State private var gender: Gender
    @State private var email: String
    @State private var phoneNumber: String
    
    init(node: FamilyTreeNode, viewModel: FamilyTreeViewModel) {
        self.node = node
        self.viewModel = viewModel
        _firstName = State(initialValue: node.firstName)
        _lastName = State(initialValue: node.lastName)
        _dateOfBirth = State(initialValue: node.dateOfBirth ?? Date())
        _gender = State(initialValue: node.gender)
        _email = State(initialValue: node.email ?? "")
        _phoneNumber = State(initialValue: node.phoneNumber ?? "")
    }
    
    var body: some View {
        Form {
            Section(header: Text("Personal Information")) {
                if isEditing {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag(Gender.male)
                        Text("Female").tag(Gender.female)
                        Text("Non-Binary").tag(Gender.nonBinary)
                        Text("Other").tag(Gender.other)
                    }
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $phoneNumber)
                        .keyboardType(.phonePad)
                } else {
                    LabeledContent("First Name", value: node.firstName)
                    LabeledContent("Last Name", value: node.lastName)
                    if let dob = node.dateOfBirth {
                        LabeledContent("Date of Birth") {
                            Text(dob, style: .date)
                        }
                    }
                    LabeledContent("Gender", value: node.gender.rawValue.capitalized)
                    if let email = node.email {
                        LabeledContent("Email", value: email)
                    }
                    if let phone = node.phoneNumber {
                        LabeledContent("Phone", value: phone)
                    }
                }
            }
            
            // Family Relationships Section
            Section("Family Relationships") {
                if !node.parentIds.isEmpty {
                    NavigationLink {
                        RelatedMembersView(
                            title: "Parents",
                            members: node.parentIds.compactMap { viewModel.nodes[$0] }
                        )
                    } label: {
                        Label("Parents (\(node.parentIds.count))", systemImage: "person.2")
                    }
                }
                
                if !node.spouseIds.isEmpty {
                    NavigationLink {
                        RelatedMembersView(
                            title: "Spouse",
                            members: node.spouseIds.compactMap { viewModel.nodes[$0] }
                        )
                    } label: {
                        Label("Spouse", systemImage: "heart")
                    }
                }
                
                if !node.childrenIds.isEmpty {
                    NavigationLink {
                        RelatedMembersView(
                            title: "Children",
                            members: node.childrenIds.compactMap { viewModel.nodes[$0] }
                        )
                    } label: {
                        Label("Children (\(node.childrenIds.count))", systemImage: "person.3")
                    }
                }
            }
            
            if node.canEdit {
                Section {
                    Button(isEditing ? "Save Changes" : "Edit") {
                        if isEditing {
                            Task {
                                var updatedNode = node
                                updatedNode.firstName = firstName
                                updatedNode.lastName = lastName
                                updatedNode.dateOfBirth = dateOfBirth
                                updatedNode.gender = gender
                                updatedNode.email = email
                                updatedNode.phoneNumber = phoneNumber
                                try? await viewModel.updateMember(updatedNode)
                                isEditing = false
                            }
                        } else {
                            isEditing = true
                        }
                    }
                    
                    if isEditing {
                        Button("Cancel", role: .cancel) {
                            isEditing = false
                            // Reset form
                            firstName = node.firstName
                            lastName = node.lastName
                            dateOfBirth = node.dateOfBirth ?? Date()
                            gender = node.gender
                            email = node.email ?? ""
                            phoneNumber = node.phoneNumber ?? ""
                        }
                    }
                }
                
                Section {
                    Button("Remove from Tree", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle("\(node.firstName) \(node.lastName)")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Remove Member",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task {
                    try? await viewModel.removeMember(node.id)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to remove this member from the family tree?")
        }
    }
}

struct RelatedMembersView: View {
    let title: String
    let members: [FamilyTreeNode]
    
    var body: some View {
        List(members) { member in
            VStack(alignment: .leading) {
                Text("\(member.firstName) \(member.lastName)")
                    .font(.headline)
                if let email = member.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(title)
    }
}

struct EditMemberView: View {
    let member: User
    @ObservedObject var viewModel: FamilyTreeViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName: String
    @State private var lastName: String
    @State private var dateOfBirth: Date
    @State private var selectedGender: Gender
    
    init(member: User, viewModel: FamilyTreeViewModel) {
        self.member = member
        self.viewModel = viewModel
        _firstName = State(initialValue: member.firstName ?? "")
        _lastName = State(initialValue: member.lastName ?? "")
        _dateOfBirth = State(initialValue: member.dateOfBirth ?? Date())
        _selectedGender = State(initialValue: member.gender ?? .other)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    Picker("Gender", selection: $selectedGender) {
                        Text("Male").tag(Gender.male)
                        Text("Female").tag(Gender.female)
                        Text("Non-Binary").tag(Gender.nonBinary)
                        Text("Other").tag(Gender.other)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    save()
                }
            )
        }
    }
    
    private func save() {
        Task {
            var updatedMember = member
            updatedMember.firstName = firstName
            updatedMember.lastName = lastName
            updatedMember.dateOfBirth = dateOfBirth
            updatedMember.gender = selectedGender
            
            do {
                try await viewModel.updateMember(updatedMember)
                if viewModel.error == nil {
                    dismiss()
                }
            } catch {
                // Handle the error appropriately
                print("Error updating member: \(error.localizedDescription)")
            }
        }
    }
}
