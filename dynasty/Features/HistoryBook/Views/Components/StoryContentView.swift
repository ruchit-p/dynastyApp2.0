import SwiftUI
import AVKit
import OSLog

struct StoryContentView: View {
    let content: String
    @State private var elements: [ContentElement] = []
    private let logger = Logger(subsystem: "com.mydynasty.StoryContentView", category: "StoryContentView")

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(elements) { element in
                ContentElementView(element: element)
            }
        }
        .onAppear {
            parseContent()
        }
    }

    private func parseContent() {
        logger.info("Parsing story content")
        guard let data = content.data(using: .utf8) else {
            logger.error("Failed to convert content string to data")
            return
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let elementsData = json["elements"] as? Data {
                elements = try JSONDecoder().decode([ContentElement].self, from: elementsData)
                logger.info("Successfully parsed \(elements.count) content elements")
            } else {
                logger.error("Invalid JSON format or missing 'elements' key")
            }
        } catch {
            logger.error("Error parsing content JSON: \(error)")
        }
    }
}
