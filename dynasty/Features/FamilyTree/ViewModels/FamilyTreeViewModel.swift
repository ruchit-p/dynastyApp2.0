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
    
    private let db = FirestoreManager.shared.getDB()
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
        db.collection("familyTrees")
            .document(treeId)
            .collection("members")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.error = error
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                for change in snapshot.documentChanges {
                    do {
                        let node = try change.document.data(as: FamilyTreeNode.self)
                        
                        switch change.type {
                        case .added, .modified:
                            self.nodes[node.id] = node
                        case .removed:
                            self.nodes.removeValue(forKey: node.id)
                        }
                    } catch {
                        self.error = error
                    }
                }
                
                // Recalculate positions when nodes change
                self.calculateNodePositions()
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
        let memberRef = db.collection("familyTrees")
            .document(treeId)
            .collection("members")
            .document(member.id)
        
        try memberRef.setData(from: member)
    }
    
    func updateMember(_ member: FamilyTreeNode) async throws {
        let memberRef = db.collection("familyTrees")
            .document(treeId)
            .collection("members")
            .document(member.id)
        
        try  memberRef.setData(from: member)
        try await loadTreeData()
    }
    
    func deleteMember(_ memberId: String) async throws {
        // First, remove references to this member from other nodes
        let batch = db.batch()
        
        if let member = nodes[memberId] {
            // Remove member and update relationships
            try await updateRelationships(for: member, batch: batch)
            try await batch.commit()
            try await loadTreeData()
        }
    }
    
    // MARK: - Relationship Operations
    
    func addParentChild(parentId: String, childId: String) async throws {
        let batch = db.batch()
        
        // Update parent
        if var parent = nodes[parentId] {
            parent.childrenIds.append(childId)
            let parentRef = db.collection("familyTrees")
                .document(treeId)
                .collection("members")
                .document(parentId)
            try batch.setData(from: parent, forDocument: parentRef)
        }
        
        // Update child
        if var child = nodes[childId] {
            child.parentIds.append(parentId)
            let childRef = db.collection("familyTrees")
                .document(treeId)
                .collection("members")
                .document(childId)
            try batch.setData(from: child, forDocument: childRef)
        }
        
        try await batch.commit()
    }
    
    func addSpouse(person1Id: String, person2Id: String) async throws {
        let batch = db.batch()
        
        // Update person1
        if var person1 = nodes[person1Id] {
            person1.spouseIds.append(person2Id)
            let person1Ref = db.collection("familyTrees")
                .document(treeId)
                .collection("members")
                .document(person1Id)
            try batch.setData(from: person1, forDocument: person1Ref)
        }
        
        // Update person2
        if var person2 = nodes[person2Id] {
            person2.spouseIds.append(person1Id)
            let person2Ref = db.collection("familyTrees")
                .document(treeId)
                .collection("members")
                .document(person2Id)
            try batch.setData(from: person2, forDocument: person2Ref)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Data Loading
    
    func loadTreeData() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let snapshot = try await db.collection("familyTrees")
            .document(treeId)
            .collection("members")
            .getDocuments()
        
        var updatedNodes: [String: FamilyTreeNode] = [:]
        for document in snapshot.documents {
            if let node = try? document.data(as: FamilyTreeNode.self) {
                updatedNodes[node.id] = node
            }
        }
        
        await MainActor.run {
            self.nodes = updatedNodes
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
