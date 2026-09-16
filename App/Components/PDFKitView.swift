import PDFKit
import SwiftUI

/// PDFKit's `PDFView` in SwiftUI. Pass a `PDFDocument` (from `Data`, a URL,
/// or built from pages); the view scales to fit and scrolls continuously.
/// See mac-ui-patterns/references/pdf-view.md.
struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument?
    var displayMode: PDFDisplayMode = .singlePageContinuous

    func makeNSView(context _: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = displayMode
        view.displaysPageBreaks = true
        view.backgroundColor = .windowBackgroundColor
        view.document = document
        return view
    }

    func updateNSView(_ view: PDFView, context _: Context) {
        if view.document !== document {
            view.document = document
            view.goToFirstPage(nil)
        }
        if view.displayMode != displayMode {
            view.displayMode = displayMode
        }
    }
}
