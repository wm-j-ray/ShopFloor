import SwiftUI
import UIKit

// MARK: - MarkdownFormatter

/// Pure text-transformation logic for markdown formatting.
/// All methods operate on plain Strings and NSRanges — no UIKit dependency, fully testable.
enum MarkdownFormatter {

    /// Toggles a heading prefix on the line containing `cursorOffset`.
    /// Applying the same level a second time removes the heading.
    /// Returns the modified text and the cursor offset delta.
    static func toggleHeading(_ level: Int, in text: String, cursorOffset: Int) -> (text: String, offsetDelta: Int) {
        let ns = text as NSString
        let safeOffset = min(cursorOffset, ns.length)
        let lineRange = ns.lineRange(for: NSRange(location: safeOffset, length: 0))
        let line = ns.substring(with: lineRange)
        let targetPrefix = String(repeating: "#", count: level) + " "

        // Strip any existing heading prefix (longest match first)
        var stripped = line
        var strippedLen = 0
        for l in stride(from: 3, through: 1, by: -1) {
            let p = String(repeating: "#", count: l) + " "
            if stripped.hasPrefix(p) {
                stripped = String(stripped.dropFirst(p.count))
                strippedLen = p.count
                break
            }
        }

        let newLine: String
        let delta: Int
        if line.hasPrefix(targetPrefix) {
            // Same level already applied — remove it
            newLine = stripped
            delta = -targetPrefix.count
        } else {
            // Apply new heading (replacing any previous level)
            newLine = targetPrefix + stripped
            delta = targetPrefix.count - strippedLen
        }

        return (ns.replacingCharacters(in: lineRange, with: newLine), delta)
    }

    /// Wraps or unwraps the selected range with `open`/`close` markers.
    /// No-op if the range is empty.
    static func toggleInline(open: String, close: String, in text: String, range: NSRange)
        -> (text: String, range: NSRange)
    {
        let ns = text as NSString
        guard range.length > 0, NSMaxRange(range) <= ns.length else { return (text, range) }
        let selected = ns.substring(with: range)

        let newSelected: String
        if selected.hasPrefix(open) && selected.hasSuffix(close) && selected.count > open.count + close.count {
            newSelected = String(selected.dropFirst(open.count).dropLast(close.count))
        } else {
            newSelected = open + selected + close
        }

        return (
            ns.replacingCharacters(in: range, with: newSelected),
            NSRange(location: range.location, length: newSelected.count)
        )
    }

    /// Replaces `range` with `[label](url)`.
    static func insertLink(label: String, url: String, in text: String, range: NSRange) -> String {
        let ns = text as NSString
        let safe = NSRange(
            location: min(range.location, ns.length),
            length:   min(range.length, ns.length - min(range.location, ns.length))
        )
        return ns.replacingCharacters(in: safe, with: "[\(label)](\(url))")
    }
}

// MARK: - MarkdownTextEditor

/// Markdown-aware UITextView wrapper with a formatting toolbar.
/// Toolbar buttons: H1 · H2 · H3 · Bold · Italic · Link · Done
///
/// Formatting is applied as markdown syntax — the caller stores and renders the markdown;
/// Karen never types syntax by hand.
struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String

    /// Called when the Link button is tapped.
    /// Receives the currently selected text and its NSRange so the parent can
    /// show a URL prompt and call back via the coordinator.
    var onLinkRequest: (_ selectedText: String, _ range: NSRange) -> Void = { _, _ in }

    /// Called once when the coordinator is created so the parent can hold a reference
    /// and call `applyLink(label:url:range:)` after collecting the URL.
    var onCoordinatorReady: (Coordinator) -> Void = { _ in }

    /// Called with `true` when the text view gains focus, `false` when it resigns.
    var onEditingChanged: (Bool) -> Void = { _ in }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = .preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 4, left: 4, bottom: 8, right: 4)
        tv.inputAccessoryView = FormattingToolbar(coordinator: context.coordinator)
        context.coordinator.textView = tv
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text { tv.text = text }
    }

    func makeCoordinator() -> Coordinator {
        let c = Coordinator(text: $text, onLinkRequest: onLinkRequest, onEditingChanged: onEditingChanged)
        onCoordinatorReady(c)
        return c
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var onLinkRequest: (String, NSRange) -> Void
        var onEditingChanged: (Bool) -> Void
        weak var textView: UITextView?

        init(text: Binding<String>,
             onLinkRequest: @escaping (String, NSRange) -> Void,
             onEditingChanged: @escaping (Bool) -> Void) {
            _text = text
            self.onLinkRequest = onLinkRequest
            self.onEditingChanged = onEditingChanged
            super.init()
            NotificationCenter.default.addObserver(
                self, selector: #selector(keyboardWillShow(_:)),
                name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.addObserver(
                self, selector: #selector(keyboardWillHide(_:)),
                name: UIResponder.keyboardWillHideNotification, object: nil)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func textViewDidChange(_ textView: UITextView) {
            self.textView = textView
            text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            onEditingChanged(true)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            onEditingChanged(false)
        }

        // MARK: Heading

        func applyHeading(_ level: Int) {
            guard let tv = textView else { return }
            let offset = tv.selectedRange.location
            let (newText, delta) = MarkdownFormatter.toggleHeading(level, in: tv.text, cursorOffset: offset)
            let newOffset = max(0, min(offset + delta, (newText as NSString).length))
            tv.text = newText
            tv.selectedRange = NSRange(location: newOffset, length: 0)
            text = newText
        }

        // MARK: Inline

        func applyBold()   { applyInline(open: "**", close: "**") }
        func applyItalic() { applyInline(open: "_",  close: "_")  }

        private func applyInline(open: String, close: String) {
            guard let tv = textView else { return }
            let (newText, newRange) = MarkdownFormatter.toggleInline(
                open: open, close: close, in: tv.text, range: tv.selectedRange
            )
            tv.text = newText
            tv.selectedRange = newRange
            text = newText
        }

        // MARK: Link

        func requestLink() {
            guard let tv = textView else { return }
            let range = tv.selectedRange
            let selected = range.length > 0 ? (tv.text as NSString).substring(with: range) : ""
            tv.resignFirstResponder()
            onLinkRequest(selected, range)
        }

        func applyLink(label: String, url: String, range: NSRange) {
            guard let tv = textView else { return }
            let newText = MarkdownFormatter.insertLink(label: label, url: url, in: tv.text, range: range)
            tv.text = newText
            text = newText
        }

        @objc func dismissKeyboard() { textView?.resignFirstResponder() }

        // MARK: Keyboard inset

        @objc private func keyboardWillShow(_ notification: Notification) {
            guard let tv = textView,
                  let info = notification.userInfo,
                  let kbFrame  = info[UIResponder.keyboardFrameEndUserInfoKey]          as? CGRect,
                  let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
                  let curve    = info[UIResponder.keyboardAnimationCurveUserInfoKey]    as? UInt,
                  let window   = tv.window
            else { return }

            let tvInWindow = tv.convert(tv.bounds, to: window)
            let overlap    = tvInWindow.maxY - kbFrame.minY
            guard overlap > 0 else { return }

            UIView.animate(withDuration: duration, delay: 0,
                           options: UIView.AnimationOptions(rawValue: curve << 16)) {
                tv.contentInset.bottom = overlap
                tv.verticalScrollIndicatorInsets.bottom = overlap
            }
            tv.scrollRangeToVisible(tv.selectedRange)
        }

        @objc private func keyboardWillHide(_ notification: Notification) {
            guard let tv = textView,
                  let info     = notification.userInfo,
                  let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
                  let curve    = info[UIResponder.keyboardAnimationCurveUserInfoKey]    as? UInt
            else { return }

            UIView.animate(withDuration: duration, delay: 0,
                           options: UIView.AnimationOptions(rawValue: curve << 16)) {
                tv.contentInset.bottom = 0
                tv.verticalScrollIndicatorInsets.bottom = 0
            }
        }
    }
}

// MARK: - FormattingToolbar

private final class FormattingToolbar: UIToolbar {
    init(coordinator: MarkdownTextEditor.Coordinator) {
        super.init(frame: CGRect(x: 0, y: 0, width: 375, height: 44))
        sizeToFit()

        let h1     = button(title: "H1")         { [weak coordinator] in coordinator?.applyHeading(1) }
        let h2     = button(title: "H2")         { [weak coordinator] in coordinator?.applyHeading(2) }
        let h3     = button(title: "H3")         { [weak coordinator] in coordinator?.applyHeading(3) }
        let bold   = button(sf: "bold")          { [weak coordinator] in coordinator?.applyBold() }
        let italic = button(sf: "italic")        { [weak coordinator] in coordinator?.applyItalic() }
        let link   = button(sf: "link")          { [weak coordinator] in coordinator?.requestLink() }
        let space  = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done   = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: coordinator,
            action: #selector(MarkdownTextEditor.Coordinator.dismissKeyboard)
        )

        items = [h1, h2, h3, space, bold, italic, link, space, done]
    }

    required init?(coder: NSCoder) { fatalError() }

    private func button(title: String, action: @escaping () -> Void) -> UIBarButtonItem {
        UIBarButtonItem(title: title, primaryAction: UIAction { _ in action() })
    }

    private func button(sf: String, action: @escaping () -> Void) -> UIBarButtonItem {
        UIBarButtonItem(image: UIImage(systemName: sf), primaryAction: UIAction { _ in action() })
    }
}
