import SwiftUI

struct UploadProgressView: View {
    @State private var dots = "."
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Uploading")
                .foregroundColor(.secondary)
            Text(dots)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)
        }
        .onReceive(timer) { _ in
            switch dots {
            case ".": dots = ".."
            case "..": dots = "..."
            default: dots = "."
            }
        }
    }
}

#Preview {
    UploadProgressView()
}
