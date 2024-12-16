import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct FamilyTreeVisualization: View {
    @State private var familyMembers: [FamilyMember] = []
    @State private var relationships: [Relationship] = []
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var selectedMember: FamilyMember?
    @State private var showingMemberSettings = false
    let familyTreeID: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ZStack {
                        // Drawing connection lines
                        ForEach(relationships) { relationship in
                            if let fromMember = familyMembers.first(where: { $0.id == relationship.fromMemberID }),
                               let toMember = familyMembers.first(where: { $0.id == relationship.toMemberID }) {
                                ConnectionLine(
                                    fromPosition: positionForMember(fromMember, in: geometry.size),
                                    toPosition: positionForMember(toMember, in: geometry.size)
                                )
                            }
                        }

                        // Drawing family member nodes
                        ForEach(familyMembers) { member in
                            FamilyMemberNodeView(member: member)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedMember?.id == member.id ? Color.blue : Color.clear, lineWidth: 2)
                                )
                                .position(positionForMember(member, in: geometry.size))
                                .onTapGesture {
                                    selectedMember = member
                                }
                        }

                        // Add buttons overlay when a member is selected
                        if let selected = selectedMember {
                            let position = positionForMember(selected, in: geometry.size)

                            // Top add button (Parent)
                            AddButton(
                                actions: [
                                    AddButtonAction(
                                        title: "Add Parent",
                                        systemImage: "person.badge.plus",
                                        action: {
                                            // Add parent action
                                        }
                                    )
                                ],
                                buttonSize: 30,
                                backgroundColor: .blue
                            )
                            .position(x: position.x, y: position.y - 60)

                            // Right add button (Partner)
                            AddButton(
                                actions: [
                                    AddButtonAction(
                                        title: "Add Partner",
                                        systemImage: "person.2",
                                        action: {
                                            // Add partner action
                                        }
                                    )
                                ],
                                buttonSize: 30,
                                backgroundColor: .green
                            )
                            .position(x: position.x + 60, y: position.y)

                            // Bottom add button (Child)
                            AddButton(
                                actions: [
                                    AddButtonAction(
                                        title: "Add Child",
                                        systemImage: "person.badge.plus",
                                        action: {
                                            // Add child action
                                        }
                                    )
                                ],
                                buttonSize: 30,
                                backgroundColor: .orange
                            )
                            .position(x: position.x, y: position.y + 60)

                            // Settings button
                            Button(action: {
                                showingMemberSettings = true
                            }) {
                                Image(systemName: "gear")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .frame(width: 30, height: 30)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            .position(x: position.x - 60, y: position.y)
                        }
                    }
                    .frame(width: max(geometry.size.width * 2, 1000),
                           height: max(geometry.size.height * 2, 1000))
                }
            }
            .sheet(isPresented: $showingMemberSettings) {
                if let member = selectedMember {
                    MemberSettingsView(
                        member: member,
                        familyTreeID: familyTreeID,
                        isAdmin: Binding(
                            get: { member.isAdmin },
                            set: { newValue in
                                // Update the member in familyMembers array
                                if let index = familyMembers.firstIndex(where: { $0.id == member.id }) {
                                    familyMembers[index].isAdmin = newValue
                                }
                            }
                        ),
                        canAddMembers: Binding(
                            get: { member.canAddMembers},
                            set: { newValue in
                                // Update the member in familyMembers array
                                if let index = familyMembers.firstIndex(where: { $0.id == member.id }) {
                                    familyMembers[index].canAddMembers = newValue
                                }
                            }
                        )
                    )
                }
            }
        }
        .onAppear {
            fetchFamilyTree()
        }
    }

    // Update the function to fetch family tree using FamilyTreeManager
    private func fetchFamilyTree() {
        FamilyTreeManager.shared.fetchFamilyTree(id: familyTreeID) { result in
            switch result {
            case .success(let familyTree):
                // After fetching the family tree, fetch family members and relationships
                self.fetchFamilyMembers(from: familyTree)
                self.fetchRelationships()
            case .failure(let error):
                print("Error fetching family tree: \(error.localizedDescription)")
            }
        }
    }

    private func fetchFamilyMembers(from familyTree: FamilyTree) {
        guard let familyTreeID = familyTree.id else {
            print("Invalid family tree ID")
            return
        }

        let familyTreeRef = Firestore.firestore().collection(Constants.Firebase.familyTreesCollection).document(familyTreeID)
        let membersRef = familyTreeRef.collection("members")

        membersRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching family members: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("No family members found")
                return
            }

            let members = documents.compactMap { doc -> FamilyMember? in
                do {
                    var member = try doc.data(as: FamilyMember.self)
                    member.id = doc.documentID
                    return member
                } catch {
                    print("Error decoding member: \(error.localizedDescription)")
                    return nil
                }
            }

            DispatchQueue.main.async {
                self.familyMembers = members
                print("Family members updated: \(self.familyMembers.count) members.")
            }
        }
    }

    private func fetchRelationships() {
        let relationshipsRef = Firestore.firestore()
            .collection(Constants.Firebase.familyTreesCollection)
            .document(familyTreeID)
            .collection("relationships")

        relationshipsRef.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching relationships: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("No relationships found")
                return
            }

            let relations = documents.compactMap { doc -> Relationship? in
                do {
                    var relationship = try doc.data(as: Relationship.self)
                    relationship.id = doc.documentID
                    return relationship
                } catch {
                    print("Error decoding relationship: \(error.localizedDescription)")
                    return nil
                }
            }

            DispatchQueue.main.async {
                self.relationships = relations
                print("Relationships updated: \(self.relationships.count) relationships.")
            }
        }
    }

    private func positionForMember(_ member: FamilyMember, in size: CGSize) -> CGPoint {
        // Your existing positioning logic
        // For example, centering if only one member
        if familyMembers.count == 1 {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }

        // Placeholder logic for node positioning
        // Implement actual layout algorithm based on relationships
        let index = familyMembers.firstIndex(where: { $0.id == member.id }) ?? 0
        let angle = Double(index) * (360.0 / Double(familyMembers.count))
        let radius: Double = 200

        let x = size.width / 2 + CGFloat(cos(angle) * radius)
        let y = size.height / 2 + CGFloat(sin(angle) * radius)

        return CGPoint(x: x, y: y)
    }
}
