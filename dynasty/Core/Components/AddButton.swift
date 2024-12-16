import SwiftUI
import Foundation
import PhotosUI

struct AddButtonAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let action: () -> Void
}

struct AddButton: View {
    @State private var isShowingDropdown = false
    let actions: [AddButtonAction]
    var buttonSize: CGFloat = 56
    var backgroundColor: Color = .green
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isShowingDropdown {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(actions) { action in
                        Button(action: {
                            action.action()
                            withAnimation {
                                isShowingDropdown = false
                            }
                        }) {
                            Label(action.title, systemImage: action.systemImage)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemBackground))
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 8)
                .offset(y: -CGFloat(actions.count * 56))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isShowingDropdown.toggle()
                }
            }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(backgroundColor)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                    .rotationEffect(.degrees(isShowingDropdown ? 45 : 0))
            }
            .padding()
        }
        .onTapGesture {
            withAnimation {
                if isShowingDropdown {
                    isShowingDropdown = false
                }
            }
        }
    }
}

// Example usage:
struct AddButtonPreview: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            AddButton(
                actions: [
                    AddButtonAction(
                        title: "Example Action",
                        systemImage: "star",
                        action: { print("Action tapped") }
                    ),
                    AddButtonAction(
                        title: "Another Action",
                        systemImage: "heart",
                        action: { print("Another action tapped") }
                    )
                ]
            )
        }
    }
}