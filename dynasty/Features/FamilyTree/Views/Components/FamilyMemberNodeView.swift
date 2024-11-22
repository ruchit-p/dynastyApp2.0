import SwiftUI

struct FamilyMemberNodeView: View {
    let member: FamilyMember
    
    init(member: FamilyMember) {
        self.member = member
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let imageURL = member.profileImageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
            }
            
            Text(member.displayName)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
} 