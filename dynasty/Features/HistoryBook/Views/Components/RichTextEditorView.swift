import SwiftUI
import PhotosUI
import AVKit
import OSLog

struct RichTextEditorView: View {
    @Binding var contentElements: [ContentElement]
    @State private var selectedRange: NSRange?
    @State private var showMediaPicker = false
    @State private var mediaPickerType: PHPickerFilter = .images
    @State private var selectedMediaURL: URL?
    @State private var player: AVPlayer?
    @State private var isEditorFocused: Bool = false
    private let logger = Logger(subsystem: "com.yourapp.RichTextEditorView", category: "RichTextEditorView")

    // Formatting State
    @State private var isBold = false
    @State private var isItalic = false
    @State private var isUnderlined = false
    @State private var highlightColor: Color?
    @State private var textColor: Color?
    @State private var alignment: ContentElement.TextAlignment = .leading

    var body: some View {
        VStack {
            // Main Content Area
            ContentScrollView(
                contentElements: $contentElements,
                selectedRange: $selectedRange,
                isEditorFocused: $isEditorFocused,
                isBold: $isBold,
                isItalic: $isItalic,
                isUnderlined: $isUnderlined,
                highlightColor: $highlightColor,
                textColor: $textColor,
                alignment: $alignment
            )

            // Toolbars
            ToolbarsView(
                isEditorFocused: isEditorFocused,
                isBold: $isBold,
                isItalic: $isItalic,
                isUnderlined: $isUnderlined,
                highlightColor: $highlightColor,
                textColor: $textColor,
                alignment: $alignment,
                mediaPickerType: $mediaPickerType,
                showMediaPicker: $showMediaPicker,
                applyFormatting: { applyFormattingToSelectedText() }
            )
        }
        .sheet(isPresented: $showMediaPicker) {
            MediaPicker(mediaType: $mediaPickerType, selectedMediaURL: $selectedMediaURL)
        }
        .onChange(of: selectedMediaURL) { oldValue, newValue in
            if let newURL = newValue {
                Task {
                    await handleMediaSelection(mediaURL: newURL)
                }
            }
        }
    }

    private func handleMediaSelection(mediaURL: URL) async {
        guard let selectedRange = selectedRange else { return }

        var elementType: ContentElement.ContentType?
        switch mediaPickerType {
        case .images:
            elementType = .image
        case .videos:
            elementType = .video
        default:
            break
        }

        if let elementType = elementType {
            let newElement = ContentElement(id: UUID().uuidString, type: elementType, value: mediaURL.absoluteString)
            if let index = contentElements.firstIndex(where: { $0.type == .text && $0.value.count >= selectedRange.location }) {
                contentElements.insert(newElement, at: index + 1)
            } else {
                contentElements.append(newElement)
            }
        }
    }

    private func updateFormattingState(from format: ContentElement.TextFormat?) {
        isBold = format?.isBold ?? false
        isItalic = format?.isItalic ?? false
        isUnderlined = format?.isUnderlined ?? false
        highlightColor = Color(hex: format?.highlightColor)
        textColor = Color(hex: format?.textColor)
        alignment = format?.alignment ?? .leading
    }

    private func applyFormattingToSelectedText() {
        guard let selectedRange = selectedRange else { return }

        if let index = contentElements.firstIndex(where: { $0.type == .text && $0.value.count >= selectedRange.location }) {
            var format = contentElements[index].format ?? ContentElement.TextFormat()
            format.isBold = isBold
            format.isItalic = isItalic
            format.isUnderlined = isUnderlined
            format.highlightColor = highlightColor?.toHex()
            format.textColor = textColor?.toHex()
            format.alignment = alignment
            contentElements[index].format = format
        }
    }
}

// MARK: - Content Scroll View
struct ContentScrollView: View {
    @Binding var contentElements: [ContentElement]
    @Binding var selectedRange: NSRange?
    @Binding var isEditorFocused: Bool
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderlined: Bool
    @Binding var highlightColor: Color?
    @Binding var textColor: Color?
    @Binding var alignment: ContentElement.TextAlignment

    var body: some View {
        ScrollView {
            VStack {
                ForEach(contentElements.indices, id: \.self) { index in
                    ElementView(
                        contentElement: $contentElements[index],
                        selectedRange: $selectedRange,
                        isEditorFocused: $isEditorFocused,
                        isBold: $isBold,
                        isItalic: $isItalic,
                        isUnderlined: $isUnderlined,
                        highlightColor: $highlightColor,
                        textColor: $textColor,
                        alignment: $alignment
                    )
                }
            }
        }
    }
}

// MARK: - Element View
struct ElementView: View {
    @Binding var contentElement: ContentElement
    @Binding var selectedRange: NSRange?
    @Binding var isEditorFocused: Bool
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderlined: Bool
    @Binding var highlightColor: Color?
    @Binding var textColor: Color?
    @Binding var alignment: ContentElement.TextAlignment

    var body: some View {
        Group {
            if contentElement.type == .text {
                TextViewWrapper(
                    text: $contentElement.value,
                    format: $contentElement.format,
                    selectedRange: $selectedRange,
                    isEditorFocused: $isEditorFocused,
                    isBold: $isBold,
                    isItalic: $isItalic,
                    isUnderlined: $isUnderlined,
                    highlightColor: $highlightColor,
                    textColor: $textColor,
                    alignment: $alignment
                )
                .frame(minHeight: 100) // Ensure a tappable area
            } else {
                ContentElementView(element: contentElement)
            }
        }
    }
}

// MARK: - TextView Wrapper
struct TextViewWrapper: View {
    @Binding var text: String
    @Binding var format: ContentElement.TextFormat?
    @Binding var selectedRange: NSRange?
    @Binding var isEditorFocused: Bool
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderlined: Bool
    @Binding var highlightColor: Color?
    @Binding var textColor: Color?
    @Binding var alignment: ContentElement.TextAlignment
    @FocusState private var localFocus: Bool

    var body: some View {
        TextView(
            text: $text,
            format: Binding(
                get: { format ?? ContentElement.TextFormat() },
                set: { format = $0 }
            ),
            selectedRange: $selectedRange,
            isEditorFocused: $isEditorFocused
        )
        .focused($localFocus)
        .onChange(of: localFocus) { oldValue, newValue in
            isEditorFocused = newValue
            if newValue {
                selectedRange = NSRange(location: text.count, length: 0)
                updateFormattingState(from: format)
            }
        }
        .onChange(of: isEditorFocused) { oldValue, newValue in
            if localFocus != newValue {
                localFocus = newValue
            }
        }
    }

    private func updateFormattingState(from format: ContentElement.TextFormat?) {
        isBold = format?.isBold ?? false
        isItalic = format?.isItalic ?? false
        isUnderlined = format?.isUnderlined ?? false
        highlightColor = Color(hex: format?.highlightColor)
        textColor = Color(hex: format?.textColor)
        alignment = format?.alignment ?? .leading
    }
}

// MARK: - Toolbars View
struct ToolbarsView: View {
    var isEditorFocused: Bool
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderlined: Bool
    @Binding var highlightColor: Color?
    @Binding var textColor: Color?
    @Binding var alignment: ContentElement.TextAlignment
    @Binding var mediaPickerType: PHPickerFilter
    @Binding var showMediaPicker: Bool
    var applyFormatting: () -> Void

    var body: some View {
        Group {
            if isEditorFocused {
                VStack {
                    FormattingToolbar(
                        isBold: $isBold,
                        isItalic: $isItalic,
                        isUnderlined: $isUnderlined,
                        highlightColor: $highlightColor,
                        textColor: $textColor,
                        alignment: $alignment,
                        onFormatChange: applyFormatting
                    )
                    MediaToolbar(
                        mediaPickerType: $mediaPickerType,
                        showMediaPicker: $showMediaPicker
                    )
                }
            }
        }
    }
}

// MARK: - Media Toolbar
struct MediaToolbar: View {
    @Binding var mediaPickerType: PHPickerFilter
    @Binding var showMediaPicker: Bool

    var body: some View {
        HStack {
            Button(action: {
                mediaPickerType = .images
                showMediaPicker = true
            }) {
                Image(systemName: "photo")
            }

            Button(action: {
                mediaPickerType = .videos
                showMediaPicker = true
            }) {
                Image(systemName: "video")
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Formatting Toolbar (No Changes)
struct FormattingToolbar: View {
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderlined: Bool
    @Binding var highlightColor: Color?
    @Binding var textColor: Color?
    @Binding var alignment: ContentElement.TextAlignment
    var onFormatChange: () -> Void

    var body: some View {
        HStack {
            Group {
                Button(action: {
                    isBold.toggle()
                    onFormatChange()
                }) {
                    Image(systemName: "bold")
                        .foregroundColor(isBold ? .accentColor : .primary)
                }

                Button(action: {
                    isItalic.toggle()
                    onFormatChange()
                }) {
                    Image(systemName: "italic")
                        .foregroundColor(isItalic ? .accentColor : .primary)
                }

                Button(action: {
                    isUnderlined.toggle()
                    onFormatChange()
                }) {
                    Image(systemName: "underline")
                        .foregroundColor(isUnderlined ? .accentColor : .primary)
                }

                ColorPicker("Highlight", selection: Binding(
                    get: { highlightColor ?? .clear },
                    set: { highlightColor = $0; onFormatChange() }
                ))
                .labelsHidden()

                ColorPicker("Text Color", selection: Binding(
                    get: { textColor ?? .primary },
                    set: { textColor = $0; onFormatChange() }
                ))
                .labelsHidden()
            }

            Spacer()

            Menu {
                Button(action: {
                    alignment = .leading
                    onFormatChange()
                }) {
                    Label("Left", systemImage: "text.alignleft")
                }
                Button(action: {
                    alignment = .center
                    onFormatChange()
                }) {
                    Label("Center", systemImage: "text.aligncenter")
                }
                Button(action: {
                    alignment = .trailing
                    onFormatChange()
                }) {
                    Label("Right", systemImage: "text.alignright")
                }
            } label: {
                Image(systemName: "text.alignleft")
            }
        }
        .padding(.bottom, 8)
    }
}
