import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FamilyTreeView: View {
    @StateObject private var viewModel: FamilyTreeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddMemberSheet = false
    @State private var showingErrorAlert = false
    @State private var selectedRelationType: RelationType = .child
    @State private var showAddButtons = false
    
    private var selectedNode: FamilyTreeNode? {
        viewModel.selectedNodeId.flatMap { viewModel.nodes[$0] }
    }
    
    init(treeId: String) {
        let userId = Auth.auth().currentUser?.uid ?? ""
        _viewModel = StateObject(wrappedValue: FamilyTreeViewModel(treeId: treeId, userId: userId))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading family tree...")
                } else if viewModel.nodes.isEmpty {
                    EmptyFamilyTreeView(viewModel: viewModel)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        ZStack {
                            // Connection lines
                            ConnectionLinesView(viewModel: viewModel)
                            
                            // Family members
                            FamilyMembersLayout(viewModel: viewModel)
                            
                            if let selectedId = viewModel.selectedNodeId,
                               let selectedNode = viewModel.nodes[selectedId] {
                                PlusButtonsOverlay(
                                    selectedNode: selectedNode,
                                    showAddButtons: $showAddButtons,
                                    user: nil,
                                    viewModel: viewModel,
                                    onAddParent: {
                                        selectedRelationType = .parent
                                        showingAddMemberSheet = true
                                    },
                                    onAddSpouse: {
                                        selectedRelationType = .spouse
                                        showingAddMemberSheet = true
                                    },
                                    onAddChild: {
                                        selectedRelationType = .child
                                        showingAddMemberSheet = true
                                    },
                                    onAddSibling: {
                                        selectedRelationType = .sibling
                                        showingAddMemberSheet = true
                                    }
                                )
                                .position(viewModel.nodePositions[selectedId]?.position ?? .zero)
                            }
                        }
                        .frame(minWidth: UIScreen.main.bounds.width * 1.5,
                               minHeight: UIScreen.main.bounds.height)
                    }
                    .coordinateSpace(name: "FamilyTree")
                }
            }
            .navigationTitle("Family Tree")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { 
                            selectedRelationType = .child
                            showingAddMemberSheet = true 
                        }) {
                            Label("Add Family Member", systemImage: "person.badge.plus")
                        }
                        
                        if let currentUserId = Auth.auth().currentUser?.uid,
                           let currentUser = viewModel.nodes[currentUserId],
                           currentUser.canEdit {
                            Button(action: { /* Show admin panel */ }) {
                                Label("Manage Tree", systemImage: "gear")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddMemberSheet) {
                AddFamilyMemberForm(viewModel: viewModel, selectedNode: selectedNode)
            }
            .sheet(item: Binding<IdentifiableString?>(
                get: { viewModel.selectedNodeId.map { IdentifiableString(id: $0) } },
                set: { newValue in viewModel.selectedNodeId = newValue?.id }
            )) { nodeId in
                if let node = viewModel.nodes[nodeId.id] {
                    MemberDetailsView(node: node, viewModel: viewModel)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Text(viewModel.error?.localizedDescription ?? "Unknown error")
            }
        }
    }
}

// MARK: - Supporting Views

struct EmptyFamilyTreeView: View {
    let viewModel: FamilyTreeViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tree")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Start Your Family Tree")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your family tree and invite family members to join.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    try? await viewModel.createFamilyTree()
                }
            }) {
                Text("Create Family Tree")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
        }
    }
}

struct ConnectionLinesView: View {
    let viewModel: FamilyTreeViewModel
    
    var body: some View {
        ZStack {
            // Parent connections
            ForEach(Array(viewModel.nodes.values)) { node in
                if !node.parentIds.isEmpty {
                    ForEach(node.parentIds, id: \.self) { parentId in
                        if let parent = viewModel.nodes[parentId] {
                            ConnectionLine(
                                start: viewModel.nodePositions[parent.id]?.position ?? .zero,
                                end: viewModel.nodePositions[node.id]?.position ?? .zero,
                                type: .parent
                            )
                            .stroke(Color.blue, lineWidth: 2)
                        }
                    }
                }
            }
            
            // Spouse connections
            ForEach(Array(viewModel.nodes.values)) { node in
                if let spouseId = node.spouseIds.first,
                   let spouse = viewModel.nodes[spouseId] {
                    ConnectionLine(
                        start: viewModel.nodePositions[node.id]?.position ?? .zero,
                        end: viewModel.nodePositions[spouseId]?.position ?? .zero,
                        type: .spouse
                    )
                    .stroke(Color.red, lineWidth: 2)
                }
            }
        }
    }
}

struct FamilyMembersLayout: View {
    let viewModel: FamilyTreeViewModel
    
    var body: some View {
        ForEach(Array(viewModel.nodes.values)) { node in
            FamilyMemberNodeView(
                member: node,
                isSelected: viewModel.selectedNodeId == node.id,
                action: { 
                    viewModel.selectedNodeId = node.id
                }
            )
            .position(viewModel.nodePositions[node.id]?.position ?? .zero)
        }
    }
}

struct IdentifiableString: Identifiable {
    let id: String
}

struct FamilyTreeView_Previews: PreviewProvider {
    static var previews: some View {
        FamilyTreeView(treeId: "preview-tree")
            .environmentObject(AuthManager())
    }
}
