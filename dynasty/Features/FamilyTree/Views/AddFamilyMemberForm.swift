import SwiftUI
import ContactsUI
import FirebaseFirestore

struct AddFamilyMemberForm: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var familyTreeViewModel: FamilyTreeViewModel

    // MARK: - State Properties
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var birthYear: String = ""

    // Since we're using `relationType` directly, we can remove `selectedRelationType`
    @Binding var relationType: RelationType

    // MARK: - Properties
    var familyTreeID: String
    var selectedMember: FamilyMember
    var user: User

    // MARK: - Initializer
    init(relationType: Binding<RelationType>, selectedMember: FamilyMember, user: User) {
        self._relationType = relationType  // Correctly initialize the @Binding property
        self.selectedMember = selectedMember
        self.user = user
        self.familyTreeID = user.familyTreeID ?? ""
        self._familyTreeViewModel = StateObject(wrappedValue: FamilyTreeViewModel(treeId: user.familyTreeID ?? "", userId: user.id!))
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Relation Type")) {
                    Picker("Relation Type", selection: $relationType) {
                        ForEach(RelationType.allCases) { relation in
                            Text(relation.displayName).tag(relation)
                        }
                    }
                }

                Section(header: Text("Member Information")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    TextField("Birth Year", text: $birthYear)
                        .keyboardType(.numberPad)
                }

                Section {
                    Button("Add \(relationType.displayName)") {
                        Task {
                            await addFamilyMember()
                            dismiss()
                        }
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty)
                }
            }
            .navigationTitle("Add \(relationType.displayName)")
        }
    }

    // MARK: - Functions

    private func addFamilyMember() async {
        guard !familyTreeID.isEmpty else {
            print("Error: User does not have a familyTreeID.")
            return
        }

        let db = Firestore.firestore()
        let familyMembersRef = db.collection("familyTrees")
            .document(familyTreeID)
            .collection("members")

        let dateOfBirth = birthYear.isEmpty ? nil : formatBirthYear(birthYear)

        let newFamilyMember = FamilyMember(
            firstName: firstName,
            lastName: lastName,
            email: "",
            dateOfBirth: dateOfBirth,
            isRegisteredUser: false
        )

        do {
            // Add the new member and get the DocumentReference
            let newMemberRef = try familyMembersRef.addDocument(from: newFamilyMember)
            // Use the document ID to add the relationship
            try await addRelationship(toMemberID: newMemberRef.documentID)
            // Refresh the tree data
            try await familyTreeViewModel.loadTreeData()
        } catch {
            print("Error adding family member: \(error.localizedDescription)")
        }
    }

    private func addRelationship(toMemberID: String) async {
        guard !familyTreeID.isEmpty else {
            print("Error: User does not have a familyTreeID.")
            return
        }
        guard let fromMemberID = selectedMember.id else {
            print("Error: Selected member does not have an ID.")
            return
        }

        let db = Firestore.firestore()
        let relationshipsRef = db.collection("familyTrees")
            .document(familyTreeID)
            .collection("relationships")

        let relationshipData: [String: Any] = [
            "fromMemberID": fromMemberID,
            "toMemberID": toMemberID,
            "relationshipType": relationType.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        do {
            try await relationshipsRef.addDocument(data: relationshipData)
            // Handle reciprocal relationship if needed
            if relationType.requiresReciprocal {
                await addReciprocalRelationship(toMemberID: toMemberID)
            }
        } catch {
            print("Error adding relationship: \(error.localizedDescription)")
        }
    }

    private func addReciprocalRelationship(toMemberID: String) async {
        guard !familyTreeID.isEmpty else {
            print("Error: User does not have a familyTreeID.")
            return
        }
        guard let fromMemberID = selectedMember.id else {
            print("Error: Selected member does not have an ID.")
            return
        }

        let db = Firestore.firestore()
        let relationshipsRef = db.collection("familyTrees")
            .document(familyTreeID)
            .collection("relationships")

        let reciprocalRelationshipType = relationType.reciprocalType.rawValue

        let reciprocalRelationshipData: [String: Any] = [
            "fromMemberID": toMemberID,
            "toMemberID": fromMemberID,
            "relationshipType": reciprocalRelationshipType,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        do {
            try await relationshipsRef.addDocument(data: reciprocalRelationshipData)
        } catch {
            print("Error adding reciprocal relationship: \(error.localizedDescription)")
        }
    }

    private func formatBirthYear(_ year: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        return dateFormatter.date(from: year)
    }
}
