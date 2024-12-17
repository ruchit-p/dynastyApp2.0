import SwiftUI
import FirebaseFirestore

struct FamilyTreeView: View {
    @StateObject private var viewModel: FamilyTreeViewModel
    @State private var showingAddMemberSheet = false
    @State private var selectedMember: FamilyTreeNode?
    
    init(treeId: String, userId: String) {
        _viewModel = StateObject(wrappedValue: FamilyTreeViewModel(treeId: treeId, userId: userId))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                // Tree Content
                if viewModel.isLoading {
                    ProgressView("Loading family tree...")
                } else if viewModel.nodes.isEmpty {
                    // Show only the user's node if no family members exist
                    if let currentUser = viewModel.getCurrentUserNode() {
                        FamilyMemberNodeView(
                            member: currentUser,
                            isSelected: selectedMember?.id == currentUser.id
                        ) {
                            selectedMember = currentUser
                        }
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                } else {
                    // Draw connection lines between related members
                    ForEach(Array(viewModel.nodes.values)) { node in
                        ForEach(node.parentIds, id: \.self) { parentId in
                            if let parent = viewModel.nodes[parentId] {
                                ConnectionLine(
                                    start: nodePosition(for: parent, in: geometry.size),
                                    end: nodePosition(for: node, in: geometry.size),
                                    type: .parent
                                )
                            }
                        }
                        
                        ForEach(node.spouseIds, id: \.self) { spouseId in
                            if let spouse = viewModel.nodes[spouseId] {
                                ConnectionLine(
                                    start: nodePosition(for: node, in: geometry.size),
                                    end: nodePosition(for: spouse, in: geometry.size),
                                    type: .spouse
                                )
                            }
                        }
                    }
                    
                    // Draw member nodes
                    ForEach(Array(viewModel.nodes.values)) { node in
                        FamilyMemberNodeView(
                            member: node,
                            isSelected: selectedMember?.id == node.id
                        ) {
                            selectedMember = node
                        }
                        .position(nodePosition(for: node, in: geometry.size))
                    }
                }
                
                // Add Member Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingAddMemberSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMemberSheet) {
            AddMemberView(viewModel: viewModel)
        }
        .onAppear {
            Task {
                do {
                    try await viewModel.loadTreeData()
                } catch {
                    print("Error loading tree data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func nodePosition(for node: FamilyTreeNode, in size: CGSize) -> CGPoint {
        // Calculate position based on relationships
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        if node.isRoot {
            return CGPoint(x: centerX, y: centerY)
        }
        
        // Position based on generation and siblings
        let generationSpacing: CGFloat = 100
        let siblingSpacing: CGFloat = 150
        
        let generation = node.generation
        let siblingIndex = viewModel.nodes.values.filter { $0.generation == generation }.firstIndex(of: node) ?? 0
        let siblingsInGeneration = viewModel.nodes.values.filter { $0.generation == generation }.count
        
        let x = centerX + (CGFloat(siblingIndex) - CGFloat(siblingsInGeneration - 1) / 2) * siblingSpacing
        let y = centerY + CGFloat(generation) * generationSpacing
        
        return CGPoint(x: x, y: y)
    }
}

struct AddMemberView: View {
    @ObservedObject var viewModel: FamilyTreeViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Form fields
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var gender: FamilyTreeNode.Gender = .unknown
    @State private var email = ""
    @State private var phoneNumber = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag(FamilyTreeNode.Gender.male)
                        Text("Female").tag(FamilyTreeNode.Gender.female)
                        Text("Other").tag(FamilyTreeNode.Gender.other)
                        Text("Unknown").tag(FamilyTreeNode.Gender.unknown)
                    }
                }
                
                Section(header: Text("Contact Information")) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Add Family Member")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Add") {
                    addMember()
                }
            )
        }
    }
    
    private func addMember() {
        Task {
            let newMember = FamilyTreeNode(
                id: UUID().uuidString,
                firstName: firstName,
                lastName: lastName,
                dateOfBirth: dateOfBirth,
                gender: gender,
                email: email.isEmpty ? nil : email,
                phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                photoURL: nil,
                parentIds: [],
                spouseIds: [],
                childrenIds: [],
                isRegisteredUser: false,
                canEdit: true,
                updatedAt: Timestamp()
            )
            
            do {
                try await viewModel.addMember(newMember)
                dismiss()
            } catch {
                // Handle error (we should add an error alert here)
                print("Error adding member: \(error.localizedDescription)")
            }
        }
    }
}

enum RelationshipType: String {
    case parent
    case spouse
}

#Preview {
    FamilyTreeView(treeId: "previewTree", userId: "previewUser")
}
