import SwiftUI
import Firebase
import FirebaseAuth

struct SendInvitationView: View {
    @StateObject private var viewModel = SendInvitationViewModel()
    @State private var inviteEmail: String = ""
    @Environment(\.dismiss) var dismiss
    let familyTreeID: String
    
    var body: some View {
        VStack {
            TextField("Email Address", text: $inviteEmail)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
            
            Button("Send Invitation") {
                sendInvitation()
            }
            .padding()
            .disabled(viewModel.isLoading)
            
            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .padding()
            }
            
            if !viewModel.invitations.isEmpty {
                List {
                    Section(header: Text("Pending Invitations")) {
                        ForEach(viewModel.invitations) { invitation in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(invitation.email)
                                        .font(.headline)
                                    Text("Invited by: \(invitation.invitedBy)")
                                        .font(.caption)
                                }
                                Spacer()
                                Button(action: {
                                    cancelInvitation(invitation.id ?? "")
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
        .padding()
        .onAppear {
            Task {
                await viewModel.fetchInvitations(for: familyTreeID)
            }
        }
    }
    
    private func sendInvitation() {
        guard !inviteEmail.isEmpty else { return }
        
        Task {
            do {
                try await viewModel.sendInvitation(
                    to: inviteEmail,
                    familyTreeId: familyTreeID,
                    invitedBy: Auth.auth().currentUser?.displayName ?? "Unknown"
                )
                await MainActor.run {
                    inviteEmail = ""
                    dismiss()
                }
            } catch {
                // Error is already handled by the ViewModel
                print("Failed to send invitation: \(error.localizedDescription)")
            }
        }
    }
    
    private func cancelInvitation(_ invitationId: String) {
        Task {
            do {
                try await viewModel.cancelInvitation(invitationId)
                await viewModel.fetchInvitations(for: familyTreeID)
            } catch {
                // Error is already handled by the ViewModel
                print("Failed to cancel invitation: \(error.localizedDescription)")
            }
        }
    }
} 
