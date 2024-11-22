import SwiftUI
import Firebase

struct SendInvitationView: View {
    @State private var inviteEmail: String = ""
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode

    var familyTreeID: String

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

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    func sendInvitation() {
        let db = Firestore.firestore()
        let referralCode = UUID().uuidString
        let expiresAt = Timestamp(date: Date().addingTimeInterval(7 * 24 * 60 * 60)) // 7 days from now

        let invitationData: [String: Any] = [
            "email": inviteEmail,
            "familyTreeID": familyTreeID,
            "referralCode": referralCode,
            "expiresAt": expiresAt,
            "accepted": false
        ]

        db.collection("invitations").addDocument(data: invitationData) { error in
            if let error = error {
                self.errorMessage = "Failed to send invitation: \(error.localizedDescription)"
            } else {
                // Optionally, send an email to the user with the referral code.
                // This could be handled via a backend service or cloud function.

                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
} 