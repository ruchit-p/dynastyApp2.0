import SwiftUI
import QuickLook
import AVKit

struct VaultItemDetailView: View {
    let item: VaultItem
    @StateObject private var viewModel: VaultItemDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(item: VaultItem) {
        self.item = item
        self._viewModel = StateObject(wrappedValue: VaultItemDetailViewModel(item: item))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else {
                content
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { viewModel.shareItem() }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive, action: { viewModel.deleteItem() }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
        .onAppear {
            viewModel.loadContent()
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(.circular)
            if let progress = viewModel.downloadProgress {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Failed to load content")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                viewModel.loadContent()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private var content: some View {
        Group {
            switch item.fileType {
            case .image:
                imageContent
            case .video:
                videoContent
            case .audio:
                audioContent
            case .document:
                documentContent
            }
        }
        .padding()
    }
    
    private var imageContent: some View {
        ScrollView {
            if let image = viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var videoContent: some View {
        Group {
            if let url = viewModel.previewURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private var audioContent: some View {
        VStack {
            if let url = viewModel.previewURL {
                AudioPlayerView(url: url)
            }
        }
    }
    
    private var documentContent: some View {
        Group {
            if let url = viewModel.previewURL {
                QuickLookPreview(url: url)
            }
        }
    }
}

class VaultItemDetailViewModel: ObservableObject {
    let item: VaultItem
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingError = false
    @Published var downloadProgress: Double?
    @Published var previewImage: UIImage?
    @Published var previewURL: URL?
    
    private let vaultManager = VaultManager.shared
    private var tempURL: URL?
    
    init(item: VaultItem) {
        self.item = item
    }
    
    func loadContent() {
        Task { @MainActor in
            isLoading = true
            downloadProgress = 0
            
            do {
                let data = try await vaultManager.downloadFile(item: item)
                await handleDownloadedData(data)
            } catch {
                self.error = error
                self.showingError = true
            }
            
            isLoading = false
        }
    }
    
    @MainActor
    private func handleDownloadedData(_ data: Data) async {
        switch item.fileType {
        case .image:
            if let image = UIImage(data: data) {
                previewImage = image
            }
        case .document, .video, .audio:
            do {
                // Create temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "\(UUID().uuidString).\(item.metadata.originalFileName)"
                let url = tempDir.appendingPathComponent(fileName)
                
                try data.write(to: url)
                tempURL = url
                previewURL = url
            } catch {
                self.error = error
                self.showingError = true
            }
        }
    }
    
    func shareItem() {
        // Implement sharing functionality
    }
    
    func deleteItem() {
        Task { @MainActor in
            isLoading = true
            
            do {
                try await vaultManager.deleteItem(item)
                // Close the detail view
            } catch {
                self.error = error
                self.showingError = true
            }
            
            isLoading = false
        }
    }
    
    deinit {
        // Clean up temporary files
        if let url = tempURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        
        init(url: URL) {
            self.url = url
            super.init()
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}

struct AudioPlayerView: View {
    let url: URL
    @StateObject private var audioPlayer = AudioPlayer()
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
            
            HStack {
                Button(action: audioPlayer.togglePlayback) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }
                
                if let duration = audioPlayer.duration {
                    Slider(value: $audioPlayer.currentTime, in: 0...duration)
                }
            }
            .padding()
            
            HStack {
                Text(formatTime(audioPlayer.currentTime))
                Spacer()
                if let duration = audioPlayer.duration {
                    Text(formatTime(duration))
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .onAppear {
            audioPlayer.setAudio(url: url)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

class AudioPlayer: ObservableObject {
    private var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval?
    private var timeObserver: Any?
    
    func setAudio(url: URL) {
        player = AVPlayer(url: url)
        setupTimeObserver()
        duration = player?.currentItem?.duration.seconds
    }
    
    func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
    
    private func setupTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }
}
