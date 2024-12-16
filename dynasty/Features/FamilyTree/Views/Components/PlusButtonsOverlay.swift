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
                HStack {
                    Spacer()
                    ZStack {
                        // Circle representing the selected member
                        FamilyMemberNodeView(member: selectedMember)
                        
                        // Top Plus Button for Parent
                        AddButton(
                            actions: [
                                AddButtonAction(
                                    title: "Add Parent",
                                    systemImage: "person.badge.plus",
                                    action: {
                                        relationType = .parent
                                        showingAddFamilyMemberForm = true
                                    }
                                )
                            ],
                            buttonSize: 30,
                            backgroundColor: .blue
                        )
                        .offset(x: 0, y: -60)
                        
                        // Right Plus Button for Partner
                        AddButton(
                            actions: [
                                AddButtonAction(
                                    title: "Add Partner",
                                    systemImage: "person.2",
                                    action: {
                                        relationType = .partner
                                        showingAddFamilyMemberForm = true
                                    }
                                )
                            ],
                            buttonSize: 30,
                            backgroundColor: .green
                        )
                        .offset(x: 60, y: 0)
                        
                        // Bottom Plus Button for Child
                        AddButton(
                            actions: [
                                AddButtonAction(
                                    title: "Add Child",
                                    systemImage: "person.badge.plus",
                                    action: {
                                        relationType = .child
                                        showingAddFamilyMemberForm = true
                                    }
                                )
                            ],
                            buttonSize: 30,
                            backgroundColor: .orange
                        )
                        .offset(x: 0, y: 60)
                        
                        // Left Plus Button for Sibling
                        AddButton(
                            actions: [
                                AddButtonAction(
                                    title: "Add Sibling",
                                    systemImage: "person.2.square.stack",
                                    action: {
                                        relationType = .sibling
                                        showingAddFamilyMemberForm = true
                                    }
                                )
                            ],
                            buttonSize: 30,
                            backgroundColor: .purple
                        )
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
