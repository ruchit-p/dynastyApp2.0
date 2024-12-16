import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class HelpAndSupportViewModel: ObservableObject {
    @Published var faqs: [FAQ] = []
    @Published var error: Error?
    @Published var isLoading = false
    @Published var isSubmitting = false
    
    private let db = Firestore.firestore()
    
    func loadFAQs() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("faqs").getDocuments()
            self.faqs = snapshot.documents.map { doc in
                let data = doc.data()
                return FAQ(
                    id: doc.documentID,
                    question: data["question"] as? String ?? "",
                    answer: data["answer"] as? String ?? ""
                )
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func submitSupportRequest(name: String, email: String, message: String) async -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        isSubmitting = true
        
        do {
            try await db.collection("supportRequests").addDocument(data: [
                "userId": userId,
                "name": name,
                "email": email,
                "message": message,
                "timestamp": FieldValue.serverTimestamp(),
                "status": "pending"
            ])
            isSubmitting = false
            return true
        } catch {
            self.error = error
            isSubmitting = false
            return false
        }
    }
}

struct FAQ: Identifiable {
    let id: String
    let question: String
    let answer: String
}

struct HelpAndSupportView: View {
    @StateObject private var viewModel = HelpAndSupportViewModel()
    @State private var showingContactForm = false
    @State private var selectedFAQ: FAQ?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Quick Actions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Actions")
                            .font(.headline)
                            .padding(.leading)
                        
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
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    
                    // Frequently Asked Questions
                    if !viewModel.faqs.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Frequently Asked Questions")
                                .font(.headline)
                                .padding(.leading)
                            
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
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                    }
                }
                
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .padding()
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
    @ObservedObject var viewModel: HelpAndSupportViewModel
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
                    TextField("Email", text: $email)
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
        }
    }
    
    private func submitForm() {
        Task {
            let success = await viewModel.submitSupportRequest(
                name: name,
                email: email,
                message: message
            )
            
            alertMessage = success
                ? "Your support request has been submitted successfully."
                : "Failed to submit support request. Please try again."
            showAlert = true
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