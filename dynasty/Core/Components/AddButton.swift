import SwiftUI
import Foundation

struct AddButton: View {
    let systemName: String
    let color: Color
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 30, height: 30)
            .shadow(radius: 2)
            .overlay(
                Image(systemName: systemName)
                    .foregroundColor(color)
            )
    }
}