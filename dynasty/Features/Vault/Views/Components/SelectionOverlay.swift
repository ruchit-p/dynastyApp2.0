import SwiftUI

struct SelectionOverlay: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)

            Circle()
                .strokeBorder(Color.white, lineWidth: 2)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue : Color.clear)
                )
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.white)
                        .opacity(isSelected ? 1 : 0)
                )
                .position(x: 20, y: 20)
        }
        .onTapGesture(perform: action)
    }
} 