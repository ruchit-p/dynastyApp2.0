import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct FamilyTreeView: View {
    @State private var familyMembers: [FamilyMember] = []
    @State private var relationships: [Relationship] = []
    @State private var user: User?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var showAddButtons: Bool = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    let db = Firestore.firestore()
    @State private var familyTreeID: String = ""
    @State private var showAdminManagement: Bool = false
    @State private var isFamilyAdmin: Bool = false
    @State private var listeners: [ListenerRegistration] = []
    @State private var showingAddFamilyMemberForm = false
    @State private var selectedRelationType: RelationType = .child
    @State private var selectedMember: FamilyMember?
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error: error)
                } else if familyMembers.isEmpty {
                    emptyStateView
                } else {
                    familyTreeContent(geometry: geometry)
                }
            }
        }
        .onAppear {
            fetchInitialUserData()
        }
        .onDisappear {
            removeListeners()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        ProgressView("Loading family tree...")
    }
    
    private func errorView(error: String) -> some View {
        VStack {
            Text("Error loading family tree")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.red)
            Button("Retry") {
                fetchInitialUserData()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Text("No family members found")
                .font(.headline)
            Button("Add First Member") {
                showingAddFamilyMemberForm = true
                selectedRelationType = .child
                selectedMember = createDefaultMember()
            }
        }
    }
    
    private func familyTreeContent(geometry: GeometryProxy) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            ZStack {
                Color.white
                    .frame(width: max(geometry.size.width * 2, 1000),
                           height: max(geometry.size.height * 2, 1000))
                
                // Drawing relationship lines
                ForEach(relationships) { relationship in
                    if let fromMember = familyMembers.first(where: { $0.id == relationship.fromMemberID }),
                       let toMember = familyMembers.first(where: { $0.id == relationship.toMemberID }) {
                        ConnectionLine(
                            fromPosition: calculateNodePosition(for: fromMember, in: geometry.size),
                            toPosition: calculateNodePosition(for: toMember, in: geometry.size)
                        )
                    }
                }
                
                // Drawing family member nodes
                ForEach(familyMembers) { member in
                    FamilyMemberNodeView(member: member)
                        .position(calculateNodePosition(for: member, in: geometry.size))
                        .onTapGesture {
                            showAddButtons.toggle()
                            selectedMember = member
                        }
                }
            }
            .frame(width: max(geometry.size.width * 2, 1000),
                   height: max(geometry.size.height * 2, 1000))
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnificationGesture())
            .gesture(dragGesture())
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Admin") {
                    showAdminManagement = true
                }
                .disabled(!isFamilyAdmin)
            }
        }
        .sheet(isPresented: $showingAddFamilyMemberForm) {
            if let user = user {
                AddFamilyMemberForm(
                    relationType: $selectedRelationType,
            selectedMember: selectedMember ?? createDefaultMember(),
            user: user
        )
            }
        }
        .sheet(isPresented: $showAdminManagement) {
            AdminManagementView(familyTreeID: familyTreeID)
        }
    }
    
    // MARK: - Helper Methods
    
    private func removeListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    private func createDefaultMember() -> FamilyMember {
        return FamilyMember(
            firstName: user?.firstName ?? "",
            lastName: user?.lastName ?? "",
            email: user?.email ?? "",
            isRegisteredUser: true
        )
    }
    
    private func calculateNodePosition(for member: FamilyMember, in size: CGSize) -> CGPoint {
        // For initial single node, center it
        if familyMembers.count == 1 {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        
        // Placeholder logic for node positioning
        // TODO: Implement actual layout algorithm based on relationships
        let index = familyMembers.firstIndex(where: { $0.id == member.id }) ?? 0
        let angle = Double(index) * (360.0 / Double(familyMembers.count))
        let radius: Double = 200

        let x = size.width / 2 + CGFloat(cos(angle) * radius)
        let y = size.height / 2 + CGFloat(sin(angle) * radius)

        return CGPoint(x: x, y: y)
    }
    
    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                self.scale = value.magnitude
            }
    }
    
    private func dragGesture() -> some Gesture {
        DragGesture()
            .onChanged { gesture in
                self.offset = gesture.translation
            }
    }
    
    // Include your existing methods like fetchInitialUserData(), fetchFamilyTreeData(), etc.
    
    private func fetchInitialUserData() {
        isLoading = true
        errorMessage = nil
        
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "No authenticated user"
            isLoading = false
            return
        }
        
        db.collection(Constants.Firebase.usersCollection)
            .document(currentUser.uid)
            .getDocument { document, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Error fetching user document: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                    return
                }
                
                guard let document = document, document.exists else {
                    DispatchQueue.main.async {
                        self.errorMessage = "User document does not exist"
                        self.isLoading = false
                    }
                    return
                }
                
                do {
                    var userData = try document.data(as: User.self)
                    userData.id = document.documentID
                    self.user = userData

                    if let familyTreeID = userData.familyTreeID, !familyTreeID.isEmpty {
                        self.familyTreeID = familyTreeID
                        self.fetchFamilyTreeData()
                    } else {
                        DispatchQueue.main.async {
                            self.errorMessage = "Family tree ID is missing; please create a family tree."
                            self.isLoading = false
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = "Error decoding user data: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                }
            }
    }
    
    private func fetchFamilyTreeData() {
        guard !familyTreeID.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = "Family tree ID is empty"
                self.isLoading = false
            }
            return
        }
        
        let familyTreeRef = db.collection(Constants.Firebase.familyTreesCollection)
            .document(familyTreeID)
        
        // Fetch the family tree document
        familyTreeRef.getDocument { document, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error fetching family tree: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            guard let document = document, document.exists else {
                DispatchQueue.main.async {
                    self.errorMessage = "Family tree document does not exist"
                    self.isLoading = false
                }
                return
            }
            
            do {
                let familyTree = try document.data(as: FamilyTree.self)
                // Update any necessary family tree properties here
                DispatchQueue.main.async {
                    self.isFamilyAdmin = familyTree.admins.contains(user?.id ?? "")
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error decoding family tree: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
            
            // Set up listeners for members and relationships
            self.setupMembersListener(familyTreeRef)
            self.setupRelationshipsListener(familyTreeRef)
        }
    }
    
    private func setupMembersListener(_ familyTreeRef: DocumentReference) {
        let listener = familyTreeRef.collection("members")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Error fetching members: \(error.localizedDescription)"
                    }
                    return
                }
                
                if let snapshot = snapshot {
                    let members = snapshot.documents.compactMap { doc -> FamilyMember? in
                        do {
                            var member = try doc.data(as: FamilyMember.self)
                            member.id = doc.documentID // Ensure the ID is set
                            return member
                        } catch {
                            print("Error decoding member: \(error.localizedDescription)")
                            return nil
                        }
                    }
                    DispatchQueue.main.async {
                        self.familyMembers = members
                        print("Family members updated: \(self.familyMembers.count) members.")
                    }
                }
            }
        listeners.append(listener)
    }
    
    private func setupRelationshipsListener(_ familyTreeRef: DocumentReference) {
        let listener = familyTreeRef.collection("relationships")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Error fetching relationships: \(error.localizedDescription)"
                    }
                    return
                }
                
                if let snapshot = snapshot {
                    let relations = snapshot.documents.compactMap { doc -> Relationship? in
                        do {
                            var relationship = try doc.data(as: Relationship.self)
                            relationship.id = doc.documentID
                            return relationship
                        } catch {
                            print("Error decoding relationship: \(error.localizedDescription)")
                            return nil
                        }
                    }
                    DispatchQueue.main.async {
                        self.relationships = relations
                    }
                }
            }
        listeners.append(listener)
    }
}
