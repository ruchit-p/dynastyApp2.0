import SwiftUI
import FirebaseFirestore

struct MemberSettingsView: View {
    @StateObject private var viewModel: MemberSettingsViewModel
    let familyTreeID: String
    @Binding var isAdmin: Bool
    @Binding var canAddMembers: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRemoveConfirmation = false
    
    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    
    init(member: FamilyMember, familyTreeID: String, isAdmin: Binding<Bool>, canAddMembers: Binding<Bool>) {
        self._viewModel = StateObject(wrappedValue: MemberSettingsViewModel(member: member))
        self.familyTreeID = familyTreeID
        self._isAdmin = isAdmin
        self._canAddMembers = canAddMembers
        
        self._firstName = State(initialValue: member.firstName)
        self._lastName = State(initialValue: member.lastName)
        self._email = State(initialValue: member.email)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text("Member Details")) {
                        TextField("First Name", text: $firstName)
                        TextField("Last Name", text: $lastName)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                    }
                    
                    Section(header: Text("Member Permissions")) {
                        Toggle("Admin Access", isOn: $isAdmin)
                        Toggle("Can Add Members", isOn: $canAddMembers)
                        Toggle("Can Edit Tree", isOn: .constant(viewModel.member?.canEdit ?? false))
                    }
                    
                    Section {
                        Button("Remove from Family Tree", role: .destructive) {
                            showRemoveConfirmation = true
                        }
                    }
                }
                .navigationTitle("Member Settings")
                .navigationBarItems(trailing: Button("Done") {
                    saveChanges()
                })
                .alert("Error", isPresented: $showError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }
                .confirmationDialog(
                    "Remove Member",
                    isPresented: $showRemoveConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Remove", role: .destructive) {
                        removeMember()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to remove this member from the family tree?")
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
        }
    }
    
    private func saveChanges() {
        guard let memberId = viewModel.member?.id else {
            showError(message: "Invalid member ID")
            return
        }
        
        // Validate required fields
        if firstName.isEmpty || lastName.isEmpty || email.isEmpty {
            showError(message: "All fields are required")
            return
        }
        
        // Validate email format
        if !isValidEmail(email) {
            showError(message: "Invalid email format")
            return
        }
        
        // Create updated member data
        let updatedData: [String: Any] = [
            "firstName": firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            "lastName": lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "isAdmin": isAdmin,
            "canAddMembers": canAddMembers,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        Task {
            do {
                try await viewModel.updateMemberSettings(
                    memberId: memberId,
                    familyTreeId: familyTreeID,
                    updatedData: updatedData
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    showError(message: "Failed to save changes: \(error.localizedDescription)")
                    // Revert state to original values if update fails
                    if let member = viewModel.member {
                        firstName = member.firstName
                        lastName = member.lastName
                        email = member.email
                        isAdmin = member.isAdmin
                        canAddMembers = member.canAddMembers
                    }
                }
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    private func removeMember() {
        guard let memberId = viewModel.member?.id else {
            showError(message: "Invalid member ID")
            return
        }
        
        Task {
            do {
                try await viewModel.removeMember(memberId: memberId, familyTreeId: familyTreeID)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    showError(message: "Failed to remove member: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Helper function for email validation
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
