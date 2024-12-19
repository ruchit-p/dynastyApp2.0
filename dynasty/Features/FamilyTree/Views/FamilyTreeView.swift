import SwiftUI
import FirebaseAuth

struct FamilyTreeView: View {
    @StateObject private var viewModel: FamilyTreeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddMemberSheet = false
    @State private var showingErrorAlert = false
    
    init(treeId: String? = nil) {
        let userId = Auth.auth().currentUser?.uid ?? ""
        _viewModel = StateObject(wrappedValue: FamilyTreeViewModel(treeId: treeId, userId: userId))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading family tree...")
                } else if viewModel.members.isEmpty {
                    EmptyFamilyTreeView(viewModel: viewModel)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        ZStack {
                            // Connection lines
                            ConnectionLinesView(familyGroups: viewModel.familyGroups)
                            
                            // Family members
                            FamilyMembersLayout(
                                familyGroups: viewModel.familyGroups,
                                selectedMember: $viewModel.selectedMember,
                                onAddParent: { viewModel.showingAddMemberSheet = true },
                                onAddSpouse: { viewModel.showingAddMemberSheet = true },
                                onAddChild: { viewModel.showingAddMemberSheet = true }
                            )
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
                        Button(action: { showingAddMemberSheet = true }) {
                            Label("Add Family Member", systemImage: "person.badge.plus")
                        }
                        
                        if let currentUser = viewModel.members.first(where: { $0.id == Auth.auth().currentUser?.uid }),
                           currentUser.isAdmin {
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
                AddFamilyMemberForm(viewModel: viewModel)
            }
            .sheet(item: $viewModel.selectedMember) { member in
                MemberDetailsView(member: member, viewModel: viewModel)
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
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
                    await viewModel.createFamilyTree()
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
    let familyGroups: FamilyTreeViewModel.FamilyGroups
    
    var body: some View {
        ZStack {
            // Parent connections
            ForEach(familyGroups.parents) { parent in
                ConnectionLine(from: parent, to: familyGroups.spouse ?? parent)
            }
            
            // Spouse connection
            if let spouse = familyGroups.spouse {
                ConnectionLine(from: spouse, to: spouse)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
            }
            
            // Children connections
            ForEach(familyGroups.children) { child in
                ConnectionLine(from: familyGroups.spouse ?? child, to: child)
            }
            
            // Sibling connections
            ForEach(familyGroups.siblings) { sibling in
                ConnectionLine(from: sibling, to: sibling)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3]))
            }
        }
    }
}

struct FamilyMembersLayout: View {
    let familyGroups: FamilyTreeViewModel.FamilyGroups
    @Binding var selectedMember: User?
    let onAddParent: () -> Void
    let onAddSpouse: () -> Void
    let onAddChild: () -> Void
    
    var body: some View {
        VStack(spacing: 60) {
            // Parents layer
            HStack(spacing: 40) {
                ForEach(familyGroups.parents) { parent in
                    FamilyMemberNode(member: parent, isSelected: parent.id == selectedMember?.id) {
                        selectedMember = parent
                    }
                }
                
                if familyGroups.parents.count < 2 {
                    AddMemberButton(action: onAddParent, label: "Add Parent")
                }
            }
            
            // Current user and spouse layer
            HStack(spacing: 40) {
                if let spouse = familyGroups.spouse {
                    FamilyMemberNode(member: spouse, isSelected: spouse.id == selectedMember?.id) {
                        selectedMember = spouse
                    }
                } else {
                    AddMemberButton(action: onAddSpouse, label: "Add Spouse")
                }
            }
            
            // Children layer
            HStack(spacing: 40) {
                ForEach(familyGroups.children) { child in
                    FamilyMemberNode(member: child, isSelected: child.id == selectedMember?.id) {
                        selectedMember = child
                    }
                }
                
                AddMemberButton(action: onAddChild, label: "Add Child")
            }
        }
    }
}

struct FamilyMemberNode: View {
    let member: User
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                if let photoURL = member.photoURL {
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.blue)
                }
                
                Text(member.firstName ?? "Unknown")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: isSelected ? 5 : 2)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct AddMemberButton: View {
    let action: () -> Void
    let label: String
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .frame(width: 80, height: 80)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 2)
        }
    }
}

struct FamilyTreeView_Previews: PreviewProvider {
    static var previews: some View {
        FamilyTreeView(treeId: "preview-tree")
            .environmentObject(AuthManager())
    }
}
