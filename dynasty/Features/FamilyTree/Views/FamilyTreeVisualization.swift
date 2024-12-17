import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct FamilyTreeVisualization: View {
    @StateObject private var viewModel: FamilyTreeViewModel
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var showingMemberSettings = false
    @State private var selectedMember: FamilyTreeNode?
    
    init(familyTreeID: String, userID: String) {
        _viewModel = StateObject(wrappedValue: FamilyTreeViewModel(treeId: familyTreeID, userId: userID))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ZStack {
                        if viewModel.isLoading {
                            ProgressView("Loading family tree...")
                        } else {
                            // Drawing connection lines
                            ForEach(Array(viewModel.nodes.values)) { node in
                                if let position = viewModel.nodePositions[node.id] {
                                    // Parent connections
                                    ForEach(node.parentIds, id: \.self) { parentId in
                                        if let parent = viewModel.nodes[parentId],
                                           let parentPosition = viewModel.nodePositions[parentId] {
                                            ConnectionLine(
                                                start: CGPoint(x: parentPosition.x, y: parentPosition.y),
                                                end: CGPoint(x: position.x, y: position.y),
                                                type: .parent
                                            )
                                            .stroke(Color.blue, lineWidth: 2)
                                        }
                                    }
                                    
                                    // Spouse connections
                                    ForEach(node.spouseIds, id: \.self) { spouseId in
                                        if let spouse = viewModel.nodes[spouseId],
                                           let spousePosition = viewModel.nodePositions[spouseId] {
                                            ConnectionLine(
                                                start: CGPoint(x: position.x, y: position.y),
                                                end: CGPoint(x: spousePosition.x, y: spousePosition.y),
                                                type: .spouse
                                            )
                                            .stroke(Color.red, lineWidth: 2)
                                        }
                                    }
                                }
                            }
                            
                            // Drawing family member nodes
                            ForEach(Array(viewModel.nodes.values)) { node in
                                if let position = viewModel.nodePositions[node.id] {
                                    FamilyMemberNodeView(
                                        member: node,
                                        isSelected: selectedMember?.id == node.id,
                                        action: {
                                            selectedMember = node
                                            showingMemberSettings = true
                                        }
                                    )
                                    .position(x: position.x, y: position.y)
                                }
                            }
                        }
                    }
                    .frame(width: max(geometry.size.width * 2, 1000),
                           height: max(geometry.size.height * 2, 1000))
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = value
                        }
                        .onEnded { _ in
                            scale = 1.0
                        }
                )
                
                // Edit Mode Toggle
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.isEditMode.toggle()
                        }) {
                            Image(systemName: viewModel.isEditMode ? "pencil.circle.fill" : "pencil.circle")
                                .font(.system(size: 24))
                                .padding()
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 3)
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showingMemberSettings) {
            if let selectedMember = selectedMember {
                let familyMember = FamilyMember(fromNode: selectedMember)
                MemberSettingsView(
                    member: familyMember,
                    familyTreeID: viewModel.treeId,
                    isAdmin: .constant(viewModel.nodes[viewModel.treeId]?.isRegisteredUser ?? false),
                    canAddMembers: .constant(false)
                )
            }
        }
    }
}
