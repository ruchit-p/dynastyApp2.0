import SwiftUI
import AVKit
import OSLog

struct ContentElementView: View {
    let element: ContentElement
    private let logger = Logger(subsystem: "com.mydynasty.ContentElementView", category: "ContentElementView")
    @State private var showError = false
    @State private var currentError: Error?
    @State private var shouldRetryImage = false
    @State private var imageLoadAttempts = 0
    @State private var imageData: Data?
    
    var body: some View {
        Group {
            switch element.type {
            case .text:
                textView
            case .image:
                imageView
            case .video:
                videoView
            case .audio:
                audioView
            }
        }
        .errorOverlay(error: currentError, isPresented: $showError) {
            currentError = nil
        }
    }
    
    private var textView: some View {
        Text(element.value)
            .modifier(TextFormatModifier(format: element.format))
    }
    
    private var imageView: some View {
        Group {
            if shouldRetryImage {
                RetryButton(action: {
                    // Re-fetch the image data
                    if let url = URL(string: element.value) {
                        loadImage(from: url)
                    }
                    shouldRetryImage = false
                    imageLoadAttempts += 1
                })
            } else {
                AsyncImage(url: URL(string: element.value)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure(let error):
                        RetryButton(action: {
                            if let url = URL(string: element.value) {
                                loadImage(from: url)
                            }
                            shouldRetryImage = false
                            imageLoadAttempts += 1
                        })
                        .onAppear {
                            logger.error("Error loading image: \(error.localizedDescription)")
                            shouldRetryImage = true
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .id(imageLoadAttempts) // Force view refresh on retry
            }
        }
    }
    
    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.currentError = error
                    self.showError = true
                    self.logger.error("Error fetching image data: \(error.localizedDescription)")
                }
                return
            }
            
            if let data = data, let _ = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.imageData = data
                    self.currentError = nil
                    self.showError = false
                    self.logger.info("Successfully fetched image data")
                }
            } else {
                let error = NSError(domain: "ContentElement", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                DispatchQueue.main.async {
                    self.currentError = error
                    self.showError = true
                    self.logger.error("Invalid image data at URL: \(url)")
                }
            }
        }.resume()
    }
    
    private var videoView: some View {
        Group {
            if let url = URL(string: element.value) {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 250)
                    .onAppear {
                        // Reset any previous errors when video loads successfully
                        currentError = nil
                        showError = false
                    }
            } else {
                RetryButton(
                    action: {
                        // Trigger a state update to retry URL parsing
                        currentError = nil
                    },
                    title: "Invalid video URL - Tap to retry"
                )
                .onAppear {
                    let error = NSError(domain: "ContentElement", 
                                     code: 1, 
                                     userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
                    logger.error("Invalid video URL: \(element.value)")
                    currentError = error
                }
            }
        }
    }
    
    private var audioView: some View {
        Group {
            if let url = URL(string: element.value) {
                AudioPlayerView(audioURL: url)
                    .onAppear {
                        // Reset any previous errors when audio loads successfully
                        currentError = nil
                        showError = false
                    }
            } else {
                RetryButton(
                    action: {
                        // Trigger a state update to retry URL parsing
                        currentError = nil
                    },
                    title: "Invalid audio URL - Tap to retry"
                )
                .onAppear {
                    let error = NSError(domain: "ContentElement", 
                                     code: 2, 
                                     userInfo: [NSLocalizedDescriptionKey: "Invalid audio URL"])
                    logger.error("Invalid audio URL: \(element.value)")
                    currentError = error
                }
            }
        }
    }
}

struct TextFormatModifier: ViewModifier {
    let format: ContentElement.TextFormat?
    
    func body(content: Content) -> some View {
        content
            .bold(format?.isBold ?? false)
            .italic(format?.isItalic ?? false)
            .underline(format?.isUnderlined ?? false)
            .foregroundColor(Color(hex: format?.textColor))
            .background(format?.highlightColor.map { Color(hex: $0) })
            .multilineTextAlignment(format?.alignment.toTextAlignment ?? .leading)
    }
}

// Helper extension for text alignment conversion
extension ContentElement.TextAlignment {
    var toTextAlignment: TextAlignment {
        switch self {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
}
