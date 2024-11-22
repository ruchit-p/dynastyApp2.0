import SwiftUI

struct PlusButtonsOverlay: View {
    let selectedMember: FamilyMember
    @Binding var showAddButtons: Bool
    @State private var showingAddFamilyMemberForm: Bool = false
    @State private var relationType: RelationType = .child
    let user: User?

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                // Position the plus buttons around the node
                HStack {
                    Spacer()
                    ZStack {
                        // Circle representing the selected member
                        FamilyMemberNodeView(member: selectedMember)
                        // Top Plus Button for Parent
                        Button(action: {
                            relationType = .parent
                            showingAddFamilyMemberForm = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.blue)
                        }
                        .offset(x: 0, y: -60)
                        // Right Plus Button for Partner
                        Button(action: {
                            relationType = .partner
                            showingAddFamilyMemberForm = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.green)
                        }
                        .offset(x: 60, y: 0)
                        // Bottom Plus Button for Child
                        Button(action: {
                            relationType = .child
                            showingAddFamilyMemberForm = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.orange)
                        }
                        .offset(x: 0, y: 60)
                        // Left Plus Button for Sibling
                        Button(action: {
                            relationType = .sibling
                            showingAddFamilyMemberForm = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.purple)
                        }
                        .offset(x: -60, y: 0)
                    }
                    Spacer()
                }
                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.black.opacity(0.5))
            .onTapGesture {
                showAddButtons = false
            }
            .sheet(isPresented: $showingAddFamilyMemberForm) {
                if let user = user {
                    AddFamilyMemberForm(
                        relationType: $relationType,
                        selectedMember: selectedMember,
                        user: user
                    )
                }
            }
        }
    }
} 
