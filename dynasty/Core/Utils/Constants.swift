import Foundation
import FirebaseFirestore

enum Constants {
    enum Firebase {
        static let usersCollection = "users"
        static let familyTreesCollection = "familyTrees"
        static let vaultsCollection = "vaults"
        static let invitationsCollection = "invitations"
        static let historyBooksCollection = "historyBooks"
        static let commentsCollection = "comments"
        static let membersSubcollection = "members"
        static let storiesSubcollection = "stories"
    }
    
    enum UserDefaults {
        static let lastActiveFamilyTreeID = "lastActiveFamilyTreeID"
    }
} 