import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case name
    case kind
    case date
    case size
    
    var id: String { self.rawValue }
}