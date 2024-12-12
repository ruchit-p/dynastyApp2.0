import SwiftUI

struct RetryButton: View {
    let action: () -> Void
    var title: String = "Tap to retry"
    var iconSize: CGFloat = 30
    var minHeight: CGFloat = 100
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: iconSize))
                .foregroundColor(.blue)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onTapGesture(perform: action)
    }
}

#Preview {
    RetryButton(action: {})
        .padding()
} 