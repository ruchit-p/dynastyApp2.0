import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct UserProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var user: User
    @State private var firstName: String
    @State private var lastName: String
    @State private var email: String
    @State private var phoneNumber: String
    let db = Firestore.firestore()

    init(currentUser: User) {
        self._user = State(initialValue: currentUser)
        self._firstName = State(initialValue: currentUser.firstName ?? "")
        self._lastName = State(initialValue: currentUser.lastName ?? "")
        self._email = State(initialValue: currentUser.email)
        self._phoneNumber = State(initialValue: currentUser.phoneNumber ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveChanges()
                }
            )
        }
    }

    private func saveChanges() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userRef = db.collection("users").document(uid)

        user.firstName = firstName
        user.lastName = lastName
        user.email = email
        user.phoneNumber = phoneNumber

        do {
            try userRef.setData(from: user) { error in
                if let error = error {
                    print("Error saving user data: \(error.localizedDescription)")
                } else {
                    dismiss()
                }
            }
        } catch {
            print("Error encoding user data: \(error.localizedDescription)")
        }
    }
}
