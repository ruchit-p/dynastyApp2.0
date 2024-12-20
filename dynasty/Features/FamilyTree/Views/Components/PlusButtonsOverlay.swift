import SwiftUI

struct PlusButtonsOverlay: View {
    let selectedNode: FamilyTreeNode
    @Binding var showAddButtons: Bool
    @State private var showingAddFamilyMemberForm: Bool = false
    @State private var relationType: RelationType = .child
    let user: User?
    @ObservedObject var viewModel: FamilyTreeViewModel
    let onAddParent: () -> Void
    let onAddSpouse: () -> Void
    let onAddChild: () -> Void
    let onAddSibling: () -> Void

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
                            isSelected: true,
                            action: {}
                        )
                        
                        // Top Plus Button for Parent
                        if selectedNode.parentIds.count < 2 {
                            AddButton(
                                actions: [
                                    AddButtonAction(
                                        title: "Add Parent",
                                        systemImage: "person.badge.plus",
                                        action: onAddParent
                                    )
                                ],
                                buttonSize: 30,
                                backgroundColor: .blue
                            )
                            .offset(y: -60)
                        }
                        
                        // Right Plus Button for Spouse
                        if selectedNode.spouseIds.isEmpty {
                            AddButton(
                                actions: [
                                    AddButtonAction(
                                        title: "Add Spouse",
                                        systemImage: "person.2",
                                        action: onAddSpouse
                                    )
                                ],
                                buttonSize: 30,
                                backgroundColor: .green
                            )
                            .offset(x: 60)
                        }
                        
                        // Bottom Plus Button for Child
                        AddButton(
                            actions: [
                                AddButtonAction(
                                    title: "Add Child",
                                    systemImage: "person.badge.plus",
                                    action: onAddChild
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
                                    action: onAddSibling
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
        }
    }
}
