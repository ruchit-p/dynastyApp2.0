import Foundation
import FirebaseFirestore
import FirebaseAuth

class CommentService {
    private let db = FirestoreManager.shared.getDB()
    
    func addComment(to storyId: String,
                   in historyBookId: String,
                   content: String,
                   parentCommentId: String? = nil,
                   completion: @escaping (Result<Comment, Error>) -> Void) {
        
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        let commentRef = db.collection(Constants.Firebase.historyBooksCollection)
            .document(historyBookId)
            .collection(Constants.Firebase.storiesSubcollection)
            .document(storyId)
            .collection("comments")
            .document()
        
        let comment = Comment(
            userID: currentUser.uid,
            content: content,
            authorName: currentUser.displayName ?? "Anonymous",
            authorImageURL: currentUser.photoURL?.absoluteString,
            likes: [],
            parentCommentId: parentCommentId,
            replyCount: 0
        )
        
        do {
            try commentRef.setData(from: comment) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(comment))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func fetchComments(for storyId: String,
                      in historyBookId: String,
                      limit: Int = 20,
                      lastComment: Comment? = nil,
                      completion: @escaping (Result<[Comment], Error>) -> Void) {
        
        var query = db.collection(Constants.Firebase.historyBooksCollection)
            .document(historyBookId)
            .collection(Constants.Firebase.storiesSubcollection)
            .document(storyId)
            .collection("comments")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        if let lastComment = lastComment,
           let lastDate = lastComment.createdAt {
            query = query.start(after: [lastDate])
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let comments = snapshot?.documents.compactMap { doc -> Comment? in
                try? doc.data(as: Comment.self)
            } ?? []
            
            completion(.success(comments))
        }
    }
    
    func deleteComment(_ commentId: String,
                      from storyId: String,
                      in historyBookId: String,
                      completion: @escaping (Result<Void, Error>) -> Void) {
        
        db.collection(Constants.Firebase.historyBooksCollection)
            .document(historyBookId)
            .collection(Constants.Firebase.storiesSubcollection)
            .document(storyId)
            .collection("comments")
            .document(commentId)
            .delete { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }
    
    func toggleLike(on commentId: String,
                   in storyId: String,
                   historyBookId: String,
                   completion: @escaping (Result<Void, Error>) -> Void) {
        
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        let commentRef = db.collection(Constants.Firebase.historyBooksCollection)
            .document(historyBookId)
            .collection(Constants.Firebase.storiesSubcollection)
            .document(storyId)
            .collection("comments")
            .document(commentId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let commentDocument: DocumentSnapshot
            do {
                try commentDocument = transaction.getDocument(commentRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let likes = commentDocument.data()?["likes"] as? [String] else {
                return nil
            }
            
            if likes.contains(currentUser.uid) {
                transaction.updateData(["likes": FieldValue.arrayRemove([currentUser.uid])], forDocument: commentRef)
            } else {
                transaction.updateData(["likes": FieldValue.arrayUnion([currentUser.uid])], forDocument: commentRef)
            }
            
            return nil
        }) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
