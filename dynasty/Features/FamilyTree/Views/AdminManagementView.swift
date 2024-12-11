import SwiftUI
import FirebaseFirestore

struct AdminManagementView: View {
    let familyTreeID: String
    @StateObject private var viewModel = AdminManagementViewModel()
    @State private var showingMemberSettings = false
    @State private var selectedMember: FamilyMember?
    @Environment(\.dismiss) private var dismiss
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Text("Family Admin Center")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding()
                    
                    List {
                        ForEach(viewModel.admins) { member in
                            HStack {
                                Text("\(member.firstName) \(member.lastName)")
                                    .font(.title3)
                                
                                Spacer()
                                
                                if member.isAdmin {
                                    Image(systemName: "person.fill.checkmark")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "person")
                                        .foregroundColor(.gray)
                                }
                                
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
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
                
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationBarItems(leading: Button("Back") {
                dismiss()
            })
            .onAppear {
                Task {
                    await viewModel.fetchAdmins(familyTreeId: familyTreeID)
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
                                toggleAdminStatus(for: member, newStatus: newValue)
                            }
                        ),
                        canAddMembers: Binding(
                            get: { member.canAddMembers },
                            set: { newValue in
                                toggleAddPermission(for: member)
                            }
                        )
                    )
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func toggleAddPermission(for member: FamilyMember) {
        guard let memberId = member.id else { 
            showError(message: "Invalid member ID")
            return 
        }
        
        Task {
            do {
                try await viewModel.updateAdminStatus(
                    memberId: memberId,
                    familyTreeId: familyTreeID,
                    isAdmin: member.isAdmin
                )
            } catch {
                await MainActor.run {
                    showError(message: "Failed to update permissions: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func toggleAdminStatus(for member: FamilyMember, newStatus: Bool) {
        guard let memberId = member.id else { 
            showError(message: "Invalid member ID")
            return 
        }
        
        Task {
            do {
                try await viewModel.updateAdminStatus(
                    memberId: memberId,
                    familyTreeId: familyTreeID,
                    isAdmin: newStatus
                )
            } catch {
                await MainActor.run {
                    showError(message: "Failed to update admin status: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
