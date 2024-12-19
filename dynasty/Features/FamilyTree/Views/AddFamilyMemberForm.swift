import SwiftUI
import ContactsUI
import FirebaseFirestore

struct AddFamilyMemberForm: View {
    @ObservedObject var viewModel: FamilyTreeViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var gender = "unknown"
    @State private var relationship = "child"
    @State private var showingError = false
    
    let relationships = [
        ("parent", "Parent"),
        ("child", "Child"),
        ("spouse", "Spouse"),
        ("sibling", "Sibling")
    ]
    
    let genders = [
        ("male", "Male"),
        ("female", "Female"),
        ("other", "Other"),
        ("unknown", "Prefer not to say")
    ]
    
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
                    
                    Picker("Gender", selection: $gender) {
                        ForEach(genders, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                }
                
                Section(header: Text("Relationship")) {
                    Picker("Relationship to You", selection: $relationship) {
                        ForEach(relationships, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                }
                
                Section {
                    Button(action: addMember) {
                        HStack {
                            Spacer()
                            Text("Add Member")
                            Spacer()
                        }
                    }
                    .disabled(email.isEmpty || firstName.isEmpty)
                }
            }
            .navigationTitle("Add Family Member")
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
    
    private func addMember() {
        Task {
            await viewModel.addMember(
                email: email,
                firstName: firstName,
                lastName: lastName,
                dateOfBirth: dateOfBirth,
                gender: gender,
                relationship: relationship
            )
            
            if viewModel.error == nil {
                dismiss()
            } else {
                showingError = true
            }
        }
    }
}

#Preview {
    AddFamilyMemberForm(viewModel: FamilyTreeViewModel(treeId: "preview-tree", userId: "preview-user"))
}
