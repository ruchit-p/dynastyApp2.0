import FirebaseFirestore

struct Invitation: Codable, Identifiable {
    @DocumentID var id: String?
    let email: String
    let familyTreeId: String
    let invitedBy: String
    let status: String
    let timestamp: Timestamp
}