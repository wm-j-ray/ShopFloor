import SwiftUI
import PDFKit

/// Full-height PDF viewer backed by PDFKit.
/// PDFView handles its own scrolling — do not embed in a ScrollView.
struct PDFCaptureView: View {
    let url: URL

    var body: some View {
        PDFKitView(url: url)
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
