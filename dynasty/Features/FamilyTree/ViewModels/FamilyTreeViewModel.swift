import Foundation
import FirebaseFirestore
import Combine
import SwiftUI

@MainActor
class FamilyTreeViewModel: ObservableObject {
    @Published private(set) var nodes: [String: FamilyTreeNode] = [:]
    @Published private(set) var nodePositions: [String: NodePosition] = [:]
    @Published private(set) var isLoading = false
    @Published var error: Error?
    @Published var selectedNodeId: String?
    @Published var isEditMode = false
    
    private let manager = FamilyTreeManager.shared
    private var cancellables = Set<AnyCancellable>()
    let treeId: String
    private let userId: String
    
    private let levelHeight: CGFloat = 120
    private let nodeWidth: CGFloat = 100
    
    init(treeId: String, userId: String) {
        self.treeId = treeId
        self.userId = userId
        setupListeners()
    }
    
    private func setupListeners() {
        // Listen for changes in the family tree members
        manager.getMembers(for: treeId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let members):
                self.nodes = members
                self.calculateNodePositions()
            case .failure(let error):
                self.error = error
            }
        }
    }
    
    private func calculateNodePositions() {
        var newPositions: [String: NodePosition] = [:]
        var nodesByLevel: [Int: [String]] = [:]
        var processed: Set<String> = []
        
        // Find root nodes (nodes without parents)
        let rootNodes = nodes.values.filter { node in
            node.parentIds.isEmpty || !node.parentIds.contains { parentId in
                nodes.keys.contains(parentId)
            }
        }
        
        // Assign levels starting from root nodes
        func assignLevels(nodeId: String, level: Int) {
            guard !processed.contains(nodeId),
                  let node = nodes[nodeId] else { return }
            
            processed.insert(nodeId)
            nodesByLevel[level, default: []].append(nodeId)
            
            // Process children
            for childId in nodes.values.filter({ $0.parentIds.contains(nodeId) }).map({ $0.id }) {
                assignLevels(nodeId: childId, level: level + 1)
            }
            
            // Process spouses on the same level
            for spouseId in node.spouseIds {
                if !processed.contains(spouseId) {
                    assignLevels(nodeId: spouseId, level: level)
                }
            }
        }
        
        // Start assigning levels from root nodes
        for node in rootNodes {
            assignLevels(nodeId: node.id, level: 0)
        }
        
        // Calculate positions based on levels
        let maxLevel = nodesByLevel.keys.max() ?? 0
        
        for level in 0...maxLevel {
            if let nodesInLevel = nodesByLevel[level] {
                let levelWidth = CGFloat(nodesInLevel.count - 1) * nodeWidth
                let startX = -levelWidth / 2
                
                for (index, nodeId) in nodesInLevel.enumerated() {
                    let x = startX + CGFloat(index) * nodeWidth
                    let y = CGFloat(level) * levelHeight
                    newPositions[nodeId] = NodePosition(x: x, y: y)
                }
            }
        }
        
        nodePositions = newPositions
    }
    
    // MARK: - Node Operations
    
    func addMember(_ member: FamilyTreeNode) async throws {
        try await manager.addMember(member, to: treeId)
        setupListeners()
    }
    
    func updateMember(_ member: FamilyTreeNode) async throws {
        try await manager.updateMember(member, in: treeId)
        setupListeners()
    }
    
    func deleteMember(_ memberId: String) async throws {
        // First, remove references to this member from other nodes
        try await manager.removeMember(memberId, from: treeId)
        setupListeners()
    }
    
    func addMember(
        email: String,
        firstName: String,
        lastName: String,
        dateOfBirth: Date,
        gender: String,
        relationship: String
    ) async {
        isLoading = true
        error = nil
        
        do {
            let newMember = FamilyTreeNode(
                id: UUID().uuidString,
                firstName: firstName,
                lastName: lastName,
                dateOfBirth: dateOfBirth,
                gender: Gender(rawValue: gender) ?? .other,
                email: email,
                phoneNumber: nil,
                photoURL: nil,
                parentIds: [],
                childrenIds: [],
                spouseIds: [],
                generation: 0,
                isRegisteredUser: false,
                canEdit: true,
                updatedAt: Timestamp()
            )
            
            try await manager.addMember(newMember, treeId: treeId, userId: userId)
            
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    // MARK: - Relationship Operations
    
    func addParentChild(parentId: String, childId: String) async throws {
        try await manager.addParentChild(parentId: parentId, childId: childId, in: treeId)
        setupListeners()
    }
    
    func addSpouse(person1Id: String, person2Id: String) async throws {
        try await manager.addSpouse(person1Id: person1Id, person2Id: person2Id, in: treeId)
        setupListeners()
    }
    
    // MARK: - Data Loading
    
    func loadTreeData() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let members = try await manager.getMembers(for: treeId)
        await MainActor.run {
            self.nodes = members
        }
    }
    
    private func updateRelationships(for member: FamilyTreeNode, batch: WriteBatch) async throws {
        // Remove from parents' children
        for parentId in member.parentIds {
            if var parent = nodes[parentId] {
                parent.childrenIds.removeAll { $0 == member.id }
                let parentRef = db.collection("familyTrees")
                    .document(treeId)
                    .collection("members")
                    .document(parentId)
                try batch.setData(from: parent, forDocument: parentRef)
            }
        }
        
        // Remove from spouse's spouses
        for spouseId in member.spouseIds {
            if var spouse = nodes[spouseId] {
                spouse.spouseIds.removeAll { $0 == member.id }
                let spouseRef = db.collection("familyTrees")
                    .document(treeId)
                    .collection("members")
                    .document(spouseId)
                try batch.setData(from: spouse, forDocument: spouseRef)
            }
        }
        
        // Remove from children's parents
        for childId in member.childrenIds {
            if var child = nodes[childId] {
                child.parentIds.removeAll { $0 == member.id }
                let childRef = db.collection("familyTrees")
                    .document(treeId)
                    .collection("members")
                    .document(childId)
                try batch.setData(from: child, forDocument: childRef)
            }
        }
        
        // Delete the member
        let memberRef = db.collection("familyTrees")
            .document(treeId)
            .collection("members")
            .document(member.id)
        batch.deleteDocument(memberRef)
    }
    
    // MARK: - Family Groups
    
    struct FamilyGroups {
        var parents: [User]
        var spouse: User?
        var children: [User]
        var siblings: [User]
        
        init(
            parents: [User] = [],
            spouse: User? = nil,
            children: [User] = [],
            siblings: [User] = []
        ) {
            self.parents = parents
            self.spouse = spouse
            self.children = children
            self.siblings = siblings
        }
    }
    
    func getFamilyGroups(for userId: String) -> FamilyGroups {
        guard let user = nodes[userId] else { return FamilyGroups() }
        
        let parents = user.parentIds.compactMap { parentId -> User? in
            guard let parent = nodes[parentId] else { return nil }
            return User(from: parent)
        }
        
        let spouse = user.spouseIds.first.flatMap { spouseId -> User? in
            guard let spouse = nodes[spouseId] else { return nil }
            return User(from: spouse)
        }
        
        let children = user.childrenIds.compactMap { childId -> User? in
            guard let child = nodes[childId] else { return nil }
            return User(from: child)
        }
        
        let siblings = user.siblingIds.compactMap { siblingId -> User? in
            guard let sibling = nodes[siblingId] else { return nil }
            return User(from: sibling)
        }
        
        return FamilyGroups(
            parents: parents,
            spouse: spouse,
            children: children,
            siblings: siblings
        )
    }
    
    // MARK: - Helper Methods
    
    func getCurrentUserNode() -> FamilyTreeNode? {
        // If the nodes are empty, create a temporary node for the current user
        if nodes.isEmpty {
            return FamilyTreeNode(
                id: userId,
                firstName: "You",  // This will be updated when we load the actual data
                lastName: "",
                dateOfBirth: nil,
                gender: .unknown,
                email: nil,
                phoneNumber: nil,
                photoURL: nil,
                parentIds: [],
                spouseIds: [],
                childrenIds: [],
                isRegisteredUser: true,
                canEdit: true,
                updatedAt: Timestamp()
            )
        }
        
        // Otherwise, find the user's node in the existing nodes
        return nodes[userId]
    }
    
    func canEdit(_ nodeId: String) -> Bool {
        guard let node = nodes[nodeId] else { return false }
        return node.canEdit
    }
    
    func getNode(_ id: String) -> FamilyTreeNode? {
        nodes[id]
    }
    
    func getParents(_ nodeId: String) -> [FamilyTreeNode] {
        guard let node = nodes[nodeId] else { return [] }
        return node.parentIds.compactMap { nodes[$0] }
    }
    
    func getSpouses(_ nodeId: String) -> [FamilyTreeNode] {
        guard let node = nodes[nodeId] else { return [] }
        return node.spouseIds.compactMap { nodes[$0] }
    }
    
    func getChildren(_ nodeId: String) -> [FamilyTreeNode] {
        guard let node = nodes[nodeId] else { return [] }
        return node.childrenIds.compactMap { nodes[$0] }
    }
}

struct NodePosition {
    let x: CGFloat
    let y: CGFloat
}
