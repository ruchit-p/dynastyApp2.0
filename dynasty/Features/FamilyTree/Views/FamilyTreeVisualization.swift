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
                            ForEach(Array(viewModel.nodes.values), id: \.id) { node in
                                if let position = viewModel.nodePositions[node.id] {
                                    // Parent connections
                                    ForEach(node.parentIds, id: \.self) { parentId in
                                        if let parent = viewModel.nodes[parentId],
                                           let parentPosition = viewModel.nodePositions[parentId] {
                                            ConnectionLine(
                                                start: parentPosition.position,
                                                end: position.position,
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
                                                start: position.position,
                                                end: spousePosition.position,
                                                type: .spouse
                                            )
                                            .stroke(Color.red, lineWidth: 2)
                                        }
                                    }
                                    
                                    // Children connections
                                    ForEach(node.childrenIds, id: \.self) { childId in
                                        if let child = viewModel.nodes[childId],
                                           let childPosition = viewModel.nodePositions[childId] {
                                            ConnectionLine(
                                                start: position.position,
                                                end: childPosition.position,
                                                type: .child
                                            )
                                            .stroke(Color.green, lineWidth: 2)
                                        }
                                    }
                                }
                            }
                            
                            // Drawing member nodes
                            ForEach(Array(viewModel.nodes.values), id: \.id) { node in
                                if let position = viewModel.nodePositions[node.id] {
                                    FamilyMemberNodeView(
                                        member: node,
                                        isSelected: selectedMember?.id == node.id,
                                        action: {
                                            selectedMember = node
                                            showingMemberSettings = true
                                        }
                                    )
                                    .position(position.position)
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
                            scale = value.magnitude
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation
                        }
                )
            }
        }
        .sheet(isPresented: $showingMemberSettings) {
            if let member = selectedMember {
                NavigationView {
                    MemberDetailsView(node: member, viewModel: viewModel)
                }
            }
        }
    }
}
