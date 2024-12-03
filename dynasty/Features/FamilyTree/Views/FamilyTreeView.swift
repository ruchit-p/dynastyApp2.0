import SwiftUI
import Firebase

struct FamilyTreeView: View {
    @StateObject private var viewModel: FamilyTreeViewModel
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var showingAddMemberSheet = false
    @State private var showingMemberDetails = false
    @State private var selectedMember: FamilyTreeNode?
    
    init(treeId: String, userId: String) {
        _viewModel = StateObject(wrappedValue: FamilyTreeViewModel(treeId: treeId, userId: userId))
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // Tree Content
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack {
                    // Tree Canvas
                    FamilyTreeCanvas(viewModel: viewModel)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value.magnitude
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: value.translation.width + offset.width,
                                        height: value.translation.height + offset.height
                                    )
                                }
                        )
                    
                    // Loading Indicator
                    if viewModel.isLoading {
                        ProgressView()
                    }
                    
                    // Error View
                    if let error = viewModel.error {
                        ErrorView(error: error)
                    }
                }
            }
            
            // Toolbar Overlay
            VStack {
                HStack {
                    // Edit Mode Toggle
                    Button(action: {
                        viewModel.isEditMode.toggle()
                    }) {
                        Image(systemName: viewModel.isEditMode ? "pencil.circle.fill" : "pencil.circle")
                            .font(.title2)
                    }
                    
                    Spacer()
                    
                    // Add Member Button (only visible in edit mode)
                    if viewModel.isEditMode {
                        Button(action: {
                            showingAddMemberSheet = true
                        }) {
                            Image(systemName: "person.badge.plus")
                                .font(.title2)
                        }
                    }
                    
                    // Reset View Button
                    Button(action: {
                        withAnimation {
                            scale = 1.0
                            offset = .zero
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                    }
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.8))
                .cornerRadius(15)
                .padding()
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingAddMemberSheet) {
            AddMemberView(viewModel: viewModel)
        }
        .sheet(item: $selectedMember) { member in
            MemberDetailsView(member: member, viewModel: viewModel)
        }
    }
}

// MARK: - Supporting Views

struct FamilyTreeCanvas: View {
    @ObservedObject var viewModel: FamilyTreeViewModel
    
    var body: some View {
        // This is a placeholder for the actual tree rendering
        // We'll implement the tree layout algorithm in the next step
        Text("Tree Canvas - Coming Soon")
    }
}

struct ErrorView: View {
    let error: Error
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text("Error")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 5)
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

struct MemberDetailsView: View {
    let member: FamilyTreeNode
    @ObservedObject var viewModel: FamilyTreeViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Personal Information")) {
                    LabeledContent("Name", value: member.fullName)
                    if let dob = member.dateOfBirth {
                        LabeledContent("Date of Birth", value: dob.formatted(date: .long, time: .omitted))
                    }
                    LabeledContent("Gender", value: member.gender.rawValue.capitalized)
                }
                
                Section(header: Text("Contact Information")) {
                    if let email = member.email {
                        LabeledContent("Email", value: email)
                    }
                    if let phone = member.phoneNumber {
                        LabeledContent("Phone", value: phone)
                    }
                }
                
                Section(header: Text("Family Connections")) {
                    NavigationLink("Parents (\(viewModel.getParents(member.id).count))") {
                        RelativesList(relatives: viewModel.getParents(member.id), relationshipType: "Parent")
                    }
                    
                    NavigationLink("Spouses (\(viewModel.getSpouses(member.id).count))") {
                        RelativesList(relatives: viewModel.getSpouses(member.id), relationshipType: "Spouse")
                    }
                    
                    NavigationLink("Children (\(viewModel.getChildren(member.id).count))") {
                        RelativesList(relatives: viewModel.getChildren(member.id), relationshipType: "Child")
                    }
                }
            }
            .navigationTitle("Member Details")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct RelativesList: View {
    let relatives: [FamilyTreeNode]
    let relationshipType: String
    
    var body: some View {
        List(relatives) { relative in
            VStack(alignment: .leading) {
                Text(relative.fullName)
                    .font(.headline)
                if let dob = relative.dateOfBirth {
                    Text(dob.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(relationshipType + "s")
    }
}

#Preview {
    FamilyTreeView(treeId: "preview", userId: "preview")
}
