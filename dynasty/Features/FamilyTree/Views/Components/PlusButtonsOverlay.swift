import SwiftUI

struct PlusButtonsOverlay: View {
    let selectedNode: FamilyTreeNode
    @Binding var showAddButtons: Bool
    @State private var showingAddFamilyMemberForm: Bool = false
    @State private var relationType: RelationType = .child
    let user: User?
    @ObservedObject var viewModel: FamilyTreeViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        // Circle representing the selected member
                        FamilyMemberNodeView(
                            member: selectedNode,
                            isSelected: true
                        ) {
                            // No action needed here
                        }
                        
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
                        .offset(y: -60)
                        
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
                        .offset(x: 60)
                        
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
                        .offset(y: 60)
                        
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
                        .offset(x: -60)
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
                AddFamilyMemberForm(viewModel: viewModel)
            }
        }
    }
}
