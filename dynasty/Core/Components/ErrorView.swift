import SwiftUI

struct ErrorView: View {
    let error: Error
    @Binding var isPresented: Bool
    var action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                if let action = action {
                    action()
                }
                isPresented = false
            }) {
                Text("Dismiss")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 8)
        )
        .padding()
    }
}

struct ErrorOverlay: ViewModifier {
    let error: Error?
    @Binding var isPresented: Bool
    var action: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented, let error = error {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                ErrorView(error: error, isPresented: $isPresented, action: action)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: isPresented)
    }
}

extension View {
    func errorOverlay(error: Error?, isPresented: Binding<Bool>, action: (() -> Void)? = nil) -> some View {
        modifier(ErrorOverlay(error: error, isPresented: isPresented, action: action))
    }
} 