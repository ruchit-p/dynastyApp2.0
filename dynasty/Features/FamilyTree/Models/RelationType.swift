enum RelationType: String, Codable, CaseIterable, Identifiable {
    case parent
    case child
    case partner
    case sibling
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .parent: return "Parent"
        case .child: return "Child"
        case .partner: return "Partner"
        case .sibling: return "Sibling"
        }
    }
    
    var reciprocalType: RelationType {
        switch self {
        case .parent: return .child
        case .child: return .parent
        case .partner: return .partner
        case .sibling: return .sibling
        }
    }
    
    var requiresReciprocal: Bool {
        switch self {
        case .parent, .child, .partner: return true
        case .sibling: return false
        }
    }
} 