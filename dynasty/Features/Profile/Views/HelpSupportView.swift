import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class HelpSupportViewModel: ObservableObject {
    @Published var faqs: [FAQ] = []
    @Published var error: Error?
    @Published var isLoading = false
    @Published var isSubmitting = false
    
    private let db = FirestoreManager.shared.getDB()
    
    func loadFAQs() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("faqs").getDocuments()
            await MainActor.run {
                self.faqs = snapshot.documents.map { doc in
                    let data = doc.data()
                    return FAQ(
                        id: doc.documentID,
                        question: data["question"] as? String ?? "",
                        answer: data["answer"] as? String ?? ""
                    )
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    func submitSupportRequest(name: String, email: String, message: String) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        isSubmitting = true
        defer { isSubmitting = false }
        
        do {
            try await db.collection("supportRequests").addDocument(data: [
                "userId": userId,
                "name": name,
                "email": email,
                "message": message,
                "timestamp": FieldValue.serverTimestamp(),
                "status": "pending"
            ])
            return true
        } catch {
            await MainActor.run {
                self.error = error
            }
            return false
        }
    }
}

struct FAQ: Identifiable, Codable {
    let id: String
    let question: String
    let answer: String
}

struct HelpAndSupportView: View {
    @StateObject private var viewModel = HelpSupportViewModel()
    @State private var showingContactForm = false
    @State private var selectedFAQ: FAQ?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    LoadingView(message: "Loading help resources...")
                } else {
                    // Quick Actions
                    SettingsSection(title: "Quick Actions") {
                        VStack(spacing: 8) {
                            Button(action: { showingContactForm = true }) {
                                SettingRow(
                                    icon: "envelope.fill",
                                    title: "Contact Support",
                                    description: "Get help from our support team",
                                    color: .blue
                                )
                            }
                            
                            Link(destination: URL(string: "https://dynasty.app/faq")!) {
                                SettingRow(
                                    icon: "questionmark.circle.fill",
                                    title: "View Full FAQ",
                                    description: "Browse our complete FAQ section",
                                    color: .green
                                )
                            }
                            
                            Link(destination: URL(string: "https://dynasty.app/privacy")!) {
                                SettingRow(
                                    icon: "lock.shield.fill",
                                    title: "Privacy Policy",
                                    description: "Read our privacy policy",
                                    color: .purple
                                )
                            }
                            
                            Link(destination: URL(string: "https://dynasty.app/terms")!) {
                                SettingRow(
                                    icon: "doc.text.fill",
                                    title: "Terms of Service",
                                    description: "View our terms of service",
                                    color: .orange
                                )
                            }
                        }
                    }
                    
                    // Frequently Asked Questions
                    if !viewModel.faqs.isEmpty {
                        SettingsSection(title: "Frequently Asked Questions") {
                            VStack(spacing: 8) {
                                ForEach(viewModel.faqs) { faq in
                                    Button(action: { selectedFAQ = faq }) {
                                        SettingRow(
                                            icon: "questionmark.circle",
                                            title: faq.question,
                                            description: "Tap to view answer",
                                            color: .gray
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                
                if let error = viewModel.error {
                    ErrorView(error: error, isPresented: .constant(true)) {
                        Task {
                            await viewModel.loadFAQs()
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Help & Support")
        .sheet(isPresented: $showingContactForm) {
            ContactSupportView(viewModel: viewModel)
        }
        .sheet(item: $selectedFAQ) { faq in
            FAQDetailView(faq: faq)
        }
        .onAppear {
            Task {
                await viewModel.loadFAQs()
            }
        }
    }
}

struct ContactSupportView: View {
    @ObservedObject var viewModel: HelpSupportViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var message = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Information")) {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section(header: Text("How can we help?")) {
                    TextEditor(text: $message)
                        .frame(height: 200)
                }
                
                if viewModel.isSubmitting {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    Button(action: submitForm) {
                        Text("Submit")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(name.isEmpty || email.isEmpty || message.isEmpty)
                }
            }
            .navigationTitle("Contact Support")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .alert("Support Request", isPresented: $showAlert) {
                Button("OK") {
                    if alertMessage.contains("submitted") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .disabled(viewModel.isSubmitting)
        }
    }
    
    private func submitForm() {
        Task {
            let success = await viewModel.submitSupportRequest(
                name: name,
                email: email,
                message: message
            )
            
            await MainActor.run {
                alertMessage = success
                    ? "Your support request has been submitted successfully."
                    : "Failed to submit support request. Please try again."
                showAlert = true
            }
        }
    }
}

struct FAQDetailView: View {
    let faq: FAQ
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(faq.question)
                        .font(.headline)
                    
                    Text(faq.answer)
                        .font(.body)
                }
                .padding()
            }
            .navigationTitle("FAQ")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

#Preview {
    NavigationView {
        HelpAndSupportView()
    }
} 