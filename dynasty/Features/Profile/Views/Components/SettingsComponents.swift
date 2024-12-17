import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .padding(.leading)
            
            VStack(spacing: 8) {
                content
            }
            .background(Color(.systemBackground))
            .cornerRadius(15)
        }
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    var showDisclosure: Bool = true
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if showDisclosure {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(description)")
    }
}

struct ToggleSettingRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(description)")
        .accessibilityValue(isOn ? "Enabled" : "Disabled")
        .accessibilityHint("Double tap to toggle setting")
    }
}

struct PickerSettingRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @Binding var selection: Int
    let options: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Picker(selection: $selection, label: Text("")) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Text(option).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(description)")
        .accessibilityValue(options[selection])
        .accessibilityHint("Double tap to change selection")
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(message)
                .foregroundColor(.secondary)
        }
    }
}

struct SettingsErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.largeTitle)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: retryAction) {
                Text("Try Again")
                    .foregroundColor(.white)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct ConfirmationDialog: ViewModifier {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let primaryAction: () -> Void
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button(primaryButtonTitle, role: .destructive, action: primaryAction)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(message)
            }
    }
}

extension View {
    func confirmationDialog(
        title: String,
        message: String,
        primaryButtonTitle: String,
        isPresented: Binding<Bool>,
        primaryAction: @escaping () -> Void
    ) -> some View {
        modifier(ConfirmationDialog(
            title: title,
            message: message,
            primaryButtonTitle: primaryButtonTitle,
            primaryAction: primaryAction,
            isPresented: isPresented
        ))
    }
} 