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
    private let db = FirestoreManager.shared.getDB()
    private var cancellables = Set<AnyCancellable>()
    let treeId: String
    private let userId: String
    
    private let levelHeight: CGFloat = 120
    private let nodeWidth: CGFloat = 100
    
    init(treeId: String, userId: String) {
        self.treeId = treeId
        self.userId = userId
        Task {
            await loadTreeData()
        }
    }
    
    // MARK: - Node Operations
    
    func addMember(_ member: User, relationship: String? = nil) async throws {
        // First add the member to the tree
        try await manager.addMember(
            email: member.email ?? "",
            to: treeId,
            relationship: relationship ?? "member"
        )
        await loadTreeData()
    }
    
    func updateMember(_ node: FamilyTreeNode) async throws {
        let updatedUser = User(
            id: node.id,
            email: node.email,
            firstName: node.firstName,
            lastName: node.lastName,
            dateOfBirth: node.dateOfBirth,
            gender: node.gender,
            phoneNumber: node.phoneNumber,
            country: nil,
            photoURL: node.photoURL,
            familyTreeID: treeId,
            historyBookID: nil,
            parentIds: node.parentIds,
            childIds: node.childrenIds,
            spouseId: node.spouseIds.first,
            siblingIds: [],
            role: .member,
            canAddMembers: node.canEdit,
            canEdit: node.canEdit
        )
        try await manager.updateMember(updatedUser, in: treeId)
        await loadTreeData()
    }
    
    func updateMember(_ user: User) async throws {
        try await manager.updateMember(user, in: treeId)
        await loadTreeData()
    }
    
    func removeMember(_ memberId: String) async throws {
        try await manager.removeMember(memberId, from: treeId)
        await loadTreeData()
    }
    
    func addMember(
        email: String,
        to treeId: String,
        relationship: String
    ) async throws {
        try await manager.addMember(email: email, to: treeId, relationship: relationship)
        await loadTreeData()
    }
    
    // MARK: - Relationship Operations
    
    func addParentChildRelationship(parentId: String, childId: String) async throws {
        try await manager.addMember(
            email: "",  // This needs to be provided by the caller
            to: treeId,
            relationship: "child"
        )
        await loadTreeData()
    }
    
    func addSpouseRelationship(person1Id: String, person2Id: String) async throws {
        try await manager.addMember(
            email: "",  // This needs to be provided by the caller
            to: treeId,
            relationship: "spouse"
        )
        await loadTreeData()
    }
    
    // MARK: - Data Loading
    
    func loadTreeData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let members = try await manager.fetchFamilyTreeMembers(familyTreeId: treeId)
            await MainActor.run {
                self.nodes = Dictionary(uniqueKeysWithValues: members.compactMap { member -> (String, FamilyTreeNode)? in
                    guard let id = member.id else { return nil }
                    return (id, FamilyTreeNode(from: member))
                })
                calculateNodePositions()
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    private func updateRelationships(for member: FamilyTreeNode, batch: WriteBatch) async throws {
        // Remove from parents' children
        for parentId in member.parentIds {
            if var parent = nodes[parentId] {
                parent.childrenIds.removeAll { $0 == member.id }
                let parentRef = db.collection(Constants.Firebase.familyTreesCollection)
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
                let spouseRef = db.collection(Constants.Firebase.familyTreesCollection)
                    .document(treeId)
                    .collection("members")
                    .document(spouseId)
                try batch.setData(from: spouse, forDocument: spouseRef)
            }
        }
        
        // Remove from children's parents
        let childrenWithThisParent = nodes.values.filter { $0.parentIds.contains(member.id) }
        for var child in childrenWithThisParent {
            child.parentIds.removeAll { $0 == member.id }
            let childRef = db.collection(Constants.Firebase.familyTreesCollection)
                .document(treeId)
                .collection("members")
                .document(child.id)
            try batch.setData(from: child, forDocument: childRef)
        }
    }
    
    // MARK: - Family Groups
    
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
        
        let siblings = nodes.values
            .filter { node in
                !node.parentIds.isEmpty && 
                !Set(node.parentIds).isDisjoint(with: Set(user.parentIds)) &&
                node.id != user.id
            }
            .map { User(from: $0) }
        
        return FamilyGroups(
            parents: parents,
            spouse: spouse,
            children: children,
            siblings: siblings
        )
    }
    
    // MARK: - Helper Methods
    
    func createNewNode(
        firstName: String,
        lastName: String,
        dateOfBirth: Date?,
        gender: Gender,
        email: String?,
        phoneNumber: String?
    ) -> FamilyTreeNode {
        FamilyTreeNode(
            id: UUID().uuidString,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth,
            gender: gender,
            email: email,
            phoneNumber: phoneNumber,
            photoURL: nil,
            parentIds: [],
            childrenIds: [],
            spouseIds: [],
            generation: 0,
            isRegisteredUser: false,
            canEdit: true,
            updatedAt: Timestamp()
        )
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
                    newPositions[nodeId] = NodePosition(position: CGPoint(x: x, y: y))
                }
            }
        }
        
        nodePositions = newPositions
    }
    
    func createFamilyTree() async throws {
        isLoading = true
        defer { isLoading = false }
        try await manager.createFamilyTree()
        await loadTreeData()
    }
    
    struct NodePosition {
        let position: CGPoint
        
        init(position: CGPoint) {
            self.position = position
        }
    }
    
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
}
