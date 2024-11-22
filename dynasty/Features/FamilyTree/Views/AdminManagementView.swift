import SwiftUI
import FirebaseFirestore

struct AdminManagementView: View {
    let familyTreeID: String
    @State private var familyMembers: [FamilyMember] = []
    @State private var showingMemberSettings = false
    @State private var selectedMember: FamilyMember?
    @State private var selectedMemberIsAdmin: Bool = false
    @State private var selectedMemberCanAddMembers: Bool = false
    @Environment(\.dismiss) private var dismiss
    let db = Firestore.firestore()
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var listeners: [ListenerRegistration] = []
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Family Admin Center")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                List {
                    ForEach(familyMembers) { member in
                        HStack {
                            Text("\(member.firstName) \(member.lastName)")
                                .font(.title3)
                            
                            Spacer()
                            
                            // Admin/Owner status icon
                            if member.isAdmin {
                                Image(systemName: "person.fill.checkmark")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "person")
                                    .foregroundColor(.gray)
                            }
                            
                            // Add permissions button
                            if member.canAddMembers {
                                Button(action: {
                                    toggleAddPermission(for: member)
                                }) {
                                    Image(systemName: "person.badge.plus.fill")
                                        .foregroundColor(.green)
                                }
                            } else {
                                Button(action: {
                                    toggleAddPermission(for: member)
                                }) {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Settings button
                            Button(action: {
                                selectedMember = member
                                showingMemberSettings = true
                            }) {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationBarItems(leading: Button("Back") {
                dismiss()
            })
            .onAppear {
                setupMembersListener()
            }
            .onDisappear {
                listeners.forEach { $0.remove() }
                listeners.removeAll()
            }
            .sheet(isPresented: $showingMemberSettings) {
                if let index = familyMembers.firstIndex(where: { $0.id == selectedMember?.id }) {
                    MemberSettingsView(
                        member: familyMembers[index],
                        familyTreeID: familyTreeID,
                        isAdmin: Binding(
                            get: { self.familyMembers[index].isAdmin },
                            set: { newValue in
                                self.familyMembers[index].isAdmin = newValue
                                self.toggleAdminStatus(for: self.familyMembers[index], newStatus: newValue)
                            }
                        ),
                        canAddMembers: Binding(
                            get: { self.familyMembers[index].canAddMembers },
                            set: { newValue in
                                self.familyMembers[index].canAddMembers = newValue
                                self.toggleAddPermission(for: self.familyMembers[index])
                            }
                        )
                    )
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func setupMembersListener() {
        let listener = db.collection("familyTrees")
            .document(familyTreeID)
            .collection("familyMembers")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching family members: \(error.localizedDescription)")
                    return
                }
                
                if let documents = snapshot?.documents {
                    let members = documents.compactMap { document in
                        var member = try? document.data(as: FamilyMember.self)
                        member?.id = document.documentID // Ensure ID is set
                        return member
                    }
                    DispatchQueue.main.async {
                        self.familyMembers = members
                    }
                }
            }
        listeners.append(listener)
    }
    
    private func toggleAddPermission(for member: FamilyMember) {
        guard let memberId = member.id else { 
            showError(message: "Invalid member ID")
            return 
        }
        
        let memberRef = db.collection("familyTrees")
            .document(familyTreeID)
            .collection("familyMembers")
            .document(memberId)
        
        memberRef.updateData([
            "canAddMembers": !member.canAddMembers
        ]) { error in
            if let error = error {
                showError(message: "Failed to update permissions: \(error.localizedDescription)")
            }
            // Do not manually fetch family members; rely on snapshot listener
        }
    }
    
    private func toggleAdminStatus(for member: FamilyMember, newStatus: Bool) {
        guard let memberId = member.id else { 
            showError(message: "Invalid member ID")
            return 
        }
        
        let memberRef = db.collection("familyTrees")
            .document(familyTreeID)
            .collection("familyMembers")
            .document(memberId)
        
        memberRef.updateData([
            "isAdmin": newStatus
        ]) { error in
            if let error = error {
                showError(message: "Failed to update admin status: \(error.localizedDescription)")
                // Revert the local state if the server update fails
                DispatchQueue.main.async {
                    if let index = familyMembers.firstIndex(where: { $0.id == member.id }) {
                        familyMembers[index].isAdmin = !newStatus
                    }
                }
            }
        }
    }
    
    private func showError(message: String) {
        DispatchQueue.main.async {
            errorMessage = message
            showError = true
        }
    }
}
