import SwiftUI

struct PlusButtonModifier: ViewModifier {
    var action: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            content
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: action) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding()
                }
            }
        }
    }
}

extension View {
    func withPlusButton(action: @escaping () -> Void) -> some View {
        self.modifier(PlusButtonModifier(action: action))
    }
} 