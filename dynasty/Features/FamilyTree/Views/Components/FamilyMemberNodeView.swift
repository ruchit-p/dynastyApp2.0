import SwiftUI

struct FamilyMemberNodeView: View {
    let member: FamilyTreeNode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(isSelected ? .blue : .gray)
                
                Text("\(member.firstName) \(member.lastName)")
                    .font(.caption)
                    .foregroundColor(isSelected ? .blue : .primary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(radius: isSelected ? 5 : 2)
        )
    }
}