import SwiftUI

struct ConnectionLine: View {
    let fromPosition: CGPoint
    let toPosition: CGPoint
    
    var body: some View {
        Path { path in
            path.move(to: fromPosition)
            path.addLine(to: toPosition)
        }
        .stroke(Color.gray, lineWidth: 2)
    }
} 