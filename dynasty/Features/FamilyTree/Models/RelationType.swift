import Foundation

enum RelationType: String, Codable, CustomStringConvertible {
    case parent
    case spouse
    case child
    case sibling
    
    var description: String {
        rawValue
    }
}