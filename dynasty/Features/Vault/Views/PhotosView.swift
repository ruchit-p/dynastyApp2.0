import SwiftUI
import os.log

struct PhotosView: View {
    @EnvironmentObject private var vaultManager: VaultManager
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedItem: VaultItem?
    @State private var showDetail = false
    @State private var error: Error?
    @State private var showError = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    private let logger = Logger(subsystem: "com.dynasty.PhotosView", category: "UI")
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(vaultManager.items.filter { $0.fileType == .image && !$0.isDeleted }) { item in
                    PhotoGridItem(item: item)
                        .onTapGesture {
                            selectedItem = item
                            showDetail = true
                        }
                }
            }
            .padding()
        }
        .navigationTitle("Photos")
        .sheet(isPresented: $showDetail, content: {
            if let item = selectedItem {
                VaultItemDetailView(document: item)
            }
        })
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}

struct PhotoGridItem: View {
    let item: VaultItem
    @EnvironmentObject private var vaultManager: VaultManager
    @EnvironmentObject private var authManager: AuthManager
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 150, height: 150)
                    .overlay {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                    }
                    .onAppear {
                        loadThumbnail()
                    }
            }
            
            Text(item.title)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
    
    private func loadThumbnail() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                guard let user = authManager.user,
                      let userId = user.id else { return }
                let data = try await vaultManager.downloadFile(item, userId: userId)
                if let image = UIImage(data: data) {
                    let thumbnailSize = CGSize(width: 300, height: 300)
                    let thumbnailImage = await image.byPreparingThumbnail(ofSize: thumbnailSize)
                    await MainActor.run {
                        self.thumbnail = thumbnailImage
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
} 
