import SwiftUI
import UIKit

struct TextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var format: ContentElement.TextFormat
    @Binding var selectedRange: NSRange?
    @Binding var isEditorFocused: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update attributed text if the content has changed
        let newAttributedString = attributedString(from: text, with: format)
        if uiView.attributedText != newAttributedString {
            uiView.attributedText = newAttributedString
        }
        
        // Update selected range if needed
        if let selectedRange = selectedRange, uiView.selectedRange != selectedRange {
            uiView.selectedRange = selectedRange
        }

        // Handle focus state
        if isEditorFocused {
            if !uiView.isFirstResponder {
                DispatchQueue.main.async {
                    uiView.becomeFirstResponder()
                }
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextView

        init(_ parent: TextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.selectedRange = textView.selectedRange
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
        }
        
        // Handle focus changes
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isEditorFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isEditorFocused = false
        }
    }

    private func attributedString(from text: String, with format: ContentElement.TextFormat) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attributedString.length)

        if format.isBold {
            attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 16), range: range)
        }
        if format.isItalic {
            attributedString.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: 16), range: range)
        }
        if format.isUnderlined {
            attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        if let highlightColor = format.highlightColor {
            attributedString.addAttribute(.backgroundColor, value: UIColor(Color(hex: highlightColor)), range: range)
        }
        if let textColor = format.textColor {
            attributedString.addAttribute(.foregroundColor, value: UIColor(Color(hex: textColor)), range: range)
        }

        let paragraphStyle = NSMutableParagraphStyle()
        switch format.alignment {
        case .leading:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .trailing:
            paragraphStyle.alignment = .right
        }
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)

        return attributedString
    }
}

extension Color {
    init(hex: String?) {
        guard let hex = hex, !hex.isEmpty else {
            self = .clear
            return
        }

        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")

        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else {
            return ""
        }

        let r = components[0]
        let g = components[1]
        let b = components[2]

        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
    }
}
