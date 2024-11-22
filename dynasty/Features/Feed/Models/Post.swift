//
//  Post.swift
//  Dynasty
//
//  Created by Ruchit Patel on 11/12/24.
//

import Foundation
import FirebaseFirestore

struct Post: Identifiable, Codable {
    @DocumentID var id: String?
    let username: String
    let date: Timestamp
    let caption: String
    let imageURL: String?
    @ServerTimestamp var timestamp: Timestamp?
    
    // Formatted date string
    var formattedDate: String {
        guard let timestamp = timestamp?.dateValue() else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: timestamp)
    }
} 