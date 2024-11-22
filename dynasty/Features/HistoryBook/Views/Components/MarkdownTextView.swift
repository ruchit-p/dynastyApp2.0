import SwiftUI
import UIKit

struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 8
        textView.text = placeholder
        textView.textColor = UIColor.placeholderText

        // Add input accessory view
        textView.inputAccessoryView = context.coordinator.createToolbar()

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if text.isEmpty && uiView.text != placeholder {
            uiView.text = placeholder
            uiView.textColor = UIColor.placeholderText
        } else if uiView.textColor == UIColor.placeholderText && !text.isEmpty {
            uiView.text = text
            uiView.textColor = UIColor.label
        } else if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView

        init(parent: MarkdownTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == UIColor.placeholderText {
                textView.text = nil
                textView.textColor = UIColor.label
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = UIColor.placeholderText
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func createToolbar() -> UIToolbar {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()

            let boldButton = UIBarButtonItem(title: "B", style: .plain, target: self, action: #selector(applyBold))
            let italicButton = UIBarButtonItem(title: "I", style: .plain, target: self, action: #selector(applyItalic))
            let headingButton = UIBarButtonItem(title: "H1", style: .plain, target: self, action: #selector(applyHeading))
            let codeButton = UIBarButtonItem(title: "<>", style: .plain, target: self, action: #selector(applyCode))
            let imageButton = UIBarButtonItem(title: "Img", style: .plain, target: self, action: #selector(insertImageSyntax))
            let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

            toolbar.items = [boldButton, italicButton, headingButton, codeButton, imageButton, flexibleSpace]

            return toolbar
        }

        @objc func applyBold() {
            wrapSelection(with: "**")
        }

        @objc func applyItalic() {
            wrapSelection(with: "_")
        }

        @objc func applyHeading() {
            insertAtStart(linePrefix: "# ")
        }

        @objc func applyCode() {
            wrapSelection(with: "`")
        }

        @objc func insertImageSyntax() {
            insertText("![Alt Text](image_url)")
        }

        private func wrapSelection(with wrapper: String) {
            guard let textView = parent.getTextView() else { return }
            if let selectedRange = textView.selectedTextRange {
                let selectedText = textView.text(in: selectedRange) ?? ""
                let newText = wrapper + selectedText + wrapper
                textView.replace(selectedRange, withText: newText)
                parent.text = textView.text
            }
        }

        private func insertAtStart(linePrefix: String) {
            guard let textView = parent.getTextView() else { return }
            if let selectedRange = textView.selectedTextRange,
               let currentLineRange = textView.textRange(from: selectedRange.start, to: selectedRange.end) {
                let currentLine = textView.text(in: currentLineRange) ?? ""
                let newText = linePrefix + currentLine
                textView.replace(currentLineRange, withText: newText)
                parent.text = textView.text
            }
        }

        private func insertText(_ text: String) {
            guard let textView = parent.getTextView() else { return }
            if let selectedRange = textView.selectedTextRange {
                textView.replace(selectedRange, withText: text)
                parent.text = textView.text
            }
        }
    }

    // Helper to get the UITextView
    func getTextView() -> UITextView? {
        UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController?.view.findTextView()
    }
}

extension UIView {
    func findTextView() -> UITextView? {
        if let textView = self as? UITextView {
            return textView
        }
        for subview in subviews {
            if let found = subview.findTextView() {
                return found
            }
        }
        return nil
    }
}
