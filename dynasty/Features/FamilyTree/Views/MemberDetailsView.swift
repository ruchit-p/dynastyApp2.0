import SwiftUI
import FirebaseAuth

struct MemberDetailsView: View {
    let member: User
    @ObservedObject var viewModel: FamilyTreeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var isEditing = false
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section {
                    HStack {
                        Spacer()
                        if let photoURL = member.photoURL {
                            AsyncImage(url: URL(string: photoURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                    
                    if let name = member.firstName {
                        LabeledContent("Name", value: name)
                    }
                    
                    if let email = member.email {
                        LabeledContent("Email", value: email)
                    }
                    
                    if let dateOfBirth = member.dateOfBirth {
                        LabeledContent("Date of Birth") {
                            Text(dateOfBirth, style: .date)
                        }
                    }
                    
                    if let gender = member.gender {
                        LabeledContent("Gender", value: gender.capitalized)
                    }
                }
                
                // Relationships Section
                Section("Family Relationships") {
                    if !viewModel.familyGroups.parents.isEmpty {
                        NavigationLink {
                            RelatedMembersView(
                                title: "Parents",
                                members: viewModel.familyGroups.parents
                            )
                        } label: {
                            Label("Parents (\(viewModel.familyGroups.parents.count))", systemImage: "person.2")
                        }
                    }
                    
                    if viewModel.familyGroups.spouse != nil {
                        NavigationLink {
                            if let spouse = viewModel.familyGroups.spouse {
                                RelatedMembersView(
                                    title: "Spouse",
                                    members: [spouse]
                                )
                            }
                        } label: {
                            Label("Spouse", systemImage: "heart")
                        }
                    }
                    
                    if !viewModel.familyGroups.children.isEmpty {
                        NavigationLink {
                            RelatedMembersView(
                                title: "Children",
                                members: viewModel.familyGroups.children
                            )
                        } label: {
                            Label("Children (\(viewModel.familyGroups.children.count))", systemImage: "person.3")
                        }
                    }
                    
                    if !viewModel.familyGroups.siblings.isEmpty {
                        NavigationLink {
                            RelatedMembersView(
                                title: "Siblings",
                                members: viewModel.familyGroups.siblings
                            )
                        } label: {
                            Label("Siblings (\(viewModel.familyGroups.siblings.count))", systemImage: "person.2.square.stack")
                        }
                    }
                }
                
                // Actions Section
                if member.id != Auth.auth().currentUser?.uid {
                    Section {
                        if member.isRegisteredUser {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Remove from Family Tree", systemImage: "person.badge.minus")
                            }
                        } else {
                            Button {
                                // Send invitation
                            } label: {
                                Label("Send Invitation", systemImage: "envelope")
                            }
                        }
                    }
                }
            }
            .navigationTitle(member.firstName ?? "Member Details")
            .navigationBarItems(
                trailing: HStack {
                    if member.id == Auth.auth().currentUser?.uid {
                        Button {
                            isEditing = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                    }
                }
            )
            .sheet(isPresented: $isEditing) {
                EditMemberView(member: member, viewModel: viewModel)
            }
            .alert("Remove Member", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    Task {
                        if let memberId = member.id {
                            await viewModel.removeMember(memberId)
                            if viewModel.error == nil {
                                dismiss()
                            }
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to remove this member from your family tree? This action cannot be undone.")
            }
        }
    }
}

struct RelatedMembersView: View {
    let title: String
    let members: [User]
    
    var body: some View {
        List(members) { member in
            VStack(alignment: .leading) {
                Text(member.firstName ?? "Unknown")
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
    @State private var gender: String
    
    init(member: User, viewModel: FamilyTreeViewModel) {
        self.member = member
        self.viewModel = viewModel
        _firstName = State(initialValue: member.firstName ?? "")
        _lastName = State(initialValue: member.lastName ?? "")
        _dateOfBirth = State(initialValue: member.dateOfBirth ?? Date())
        _gender = State(initialValue: member.gender ?? "unknown")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                        Text("Other").tag("other")
                        Text("Prefer not to say").tag("unknown")
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
            updatedMember.gender = gender
            
            await viewModel.updateMember(updatedMember)
            if viewModel.error == nil {
                dismiss()
            }
        }
    }
}

