import SwiftUI
import PDFKit

/// SwiftUI view for the action extension
struct ActionView: View {
    @ObservedObject var viewModel: NotesViewModel
    let onDone: () -> Void
    
    @State private var selectedAnnotation: PDFAnnotation?
    @State private var pdfViewRef = PDFViewReference()
    @State private var currentZoom: CGFloat = 1.0
    @State private var searchText = ""
    @State private var searchResults: [PDFSelection] = []
    @State private var currentSearchIndex = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar
            
            Divider()
            
            // Main content
            HSplitView {
                // PDF Viewer (left side)
                pdfViewer
                    .frame(minWidth: 400)
                
                // Notes Sidebar (right side)
                NotesSidebarView(
                    viewModel: viewModel,
                    searchText: $searchText,
                    searchResults: searchResults,
                    currentSearchIndex: currentSearchIndex,
                    onSearch: performSearch,
                    onNextResult: nextResult,
                    onPreviousResult: previousResult,
                    onClearSearch: clearSearch,
                    onNavigateToNote: navigateToNote
                )
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            currentZoom = viewModel.zoomScale
        }
        .onChange(of: viewModel.zoomScale) { newZoom in
            if abs(currentZoom - newZoom) > 0.001 {
                currentZoom = newZoom
                pdfViewRef.pdfView?.scaleFactor = newZoom
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.PDFViewScaleChanged)) { notification in
            guard let pdfView = notification.object as? PDFView,
                  pdfView === pdfViewRef.pdfView else {
                return
            }
            let newScale = pdfView.scaleFactor
            if abs(currentZoom - newScale) > 0.001 {
                currentZoom = newScale
                viewModel.zoomScale = newScale
            }
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            Text("Reader")
                .font(.system(size: 14, weight: .semibold))
            
            Spacer()
            
            // Zoom controls
            if viewModel.getDocument() != nil {
                HStack(spacing: 4) {
                    Button(action: zoomOut) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(currentZoom <= NotesViewModel.zoomPresets.first!)
                    
                    Text("\(Int(currentZoom * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                    
                    Button(action: zoomIn) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(currentZoom >= NotesViewModel.zoomPresets.last!)
                }
            }
            
            Spacer()
            
            Button("Done") {
                viewModel.saveDocument()
                onDone()
            }
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - PDF Viewer
    
    private var pdfViewer: some View {
        Group {
            if let document = viewModel.getDocument() {
                ExtensionPDFViewContainer(
                    document: document,
                    pdfViewRef: pdfViewRef,
                    zoomScale: currentZoom,
                    highlightColor: viewModel.highlightColor,
                    onHighlightClicked: handleHighlightClicked,
                    onMultiLineHighlight: handleMultiLineHighlight,
                    onDeleteHighlight: handleDeleteHighlight
                )
            } else if viewModel.isLoading {
                loadingView
            } else {
                emptyPDFView
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading PDF...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyPDFView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No PDF loaded")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Open a PDF in Preview and use the Share menu to access Reader.")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Search Actions
    
    private func performSearch() {
        guard let document = viewModel.getDocument(),
              !searchText.isEmpty else {
            clearSearch()
            return
        }
        
        searchResults = document.findString(searchText, withOptions: .caseInsensitive)
        
        if !searchResults.isEmpty {
            currentSearchIndex = 0
            goToSearchResult(at: 0)
        }
    }
    
    private func nextResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
        goToSearchResult(at: currentSearchIndex)
    }
    
    private func previousResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
        goToSearchResult(at: currentSearchIndex)
    }
    
    private func goToSearchResult(at index: Int) {
        guard index < searchResults.count,
              let pdfView = pdfViewRef.pdfView else { return }
        
        let selection = searchResults[index]
        pdfView.setCurrentSelection(selection, animate: true)
        pdfView.scrollSelectionToVisible(nil)
    }
    
    private func clearSearch() {
        searchResults = []
        currentSearchIndex = 0
        pdfViewRef.pdfView?.clearSelection()
    }
    
    // MARK: - Actions
    
    private func zoomIn() {
        guard let nextZoom = NotesViewModel.zoomPresets.first(where: { $0 > currentZoom }) else { return }
        currentZoom = nextZoom
        viewModel.zoomScale = nextZoom
        pdfViewRef.pdfView?.scaleFactor = nextZoom
    }
    
    private func zoomOut() {
        guard let prevZoom = NotesViewModel.zoomPresets.last(where: { $0 < currentZoom }) else { return }
        currentZoom = prevZoom
        viewModel.zoomScale = prevZoom
        pdfViewRef.pdfView?.scaleFactor = prevZoom
    }
    
    private func handleHighlightClicked(_ annotation: PDFAnnotation, _ page: PDFPage) {
        guard let document = viewModel.getDocument(),
              let pageIndex = (0..<document.pageCount).first(where: { document.page(at: $0) == page }) else {
            return
        }
        
        // Find note matching this annotation, or create a new one
        if let note = viewModel.notes.first(where: {
            $0.pageIndex == pageIndex && $0.bounds == annotation.bounds
        }) {
            viewModel.selectNote(note)
            viewModel.startEditing(note)
        } else {
            // Create a note entry for this highlight so user can add notes
            let text = page.selection(for: annotation.bounds)?.string ?? ""
            viewModel.addHighlightNote(
                pageIndex: pageIndex,
                bounds: annotation.bounds,
                text: text,
                color: annotation.color ?? .yellow
            )
        }
    }
    
    private func handleMultiLineHighlight(_ highlights: [(page: PDFPage, bounds: CGRect)], _ combinedText: String, _ color: NSColor) {
        viewModel.addMultiLineHighlight(highlights: highlights, text: combinedText, color: color)
    }
    
    private func handleDeleteHighlight(_ annotation: PDFAnnotation, _ page: PDFPage) {
        viewModel.deleteHighlightByAnnotation(annotation, on: page)
    }
    
    private func navigateToNote(_ note: NoteAnnotation) {
        viewModel.selectNote(note)
        
        guard let document = viewModel.getDocument(),
              let page = document.page(at: note.pageIndex),
              let pdfView = pdfViewRef.pdfView else { return }
        
        pdfView.go(to: page)
        let destination = PDFDestination(page: page, at: CGPoint(x: note.bounds.minX, y: note.bounds.maxY))
        pdfView.go(to: destination)
    }
}

/// Reference holder for PDFView
class PDFViewReference: ObservableObject {
    weak var pdfView: PDFView?
}

/// Container for PDFView in extension
struct ExtensionPDFViewContainer: NSViewRepresentable {
    let document: PDFDocument
    let pdfViewRef: PDFViewReference
    let zoomScale: CGFloat
    let highlightColor: NSColor
    let onHighlightClicked: (PDFAnnotation, PDFPage) -> Void
    let onMultiLineHighlight: ([(page: PDFPage, bounds: CGRect)], String, NSColor) -> Void
    let onDeleteHighlight: (PDFAnnotation, PDFPage) -> Void

    func makeNSView(context: Context) -> PDFView {
        let pdfView = HighlightablePDFView()
        let minScale = NotesViewModel.zoomPresets.first ?? 0.5
        let maxScale = NotesViewModel.zoomPresets.last ?? 4.0
        pdfView.autoScales = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.minScaleFactor = minScale
        pdfView.maxScaleFactor = maxScale
        pdfView.document = document
        pdfView.scaleFactor = min(max(zoomScale, minScale), maxScale)
        pdfView.highlightColor = highlightColor
        pdfView.onAnnotationClicked = { annotation, page in
            if annotation.type == "Highlight" {
                onHighlightClicked(annotation, page)
            }
        }
        pdfView.onMultiLineHighlight = onMultiLineHighlight
        pdfView.onDeleteHighlight = onDeleteHighlight
        
        pdfViewRef.pdfView = pdfView
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        let minScale = NotesViewModel.zoomPresets.first ?? 0.5
        let maxScale = NotesViewModel.zoomPresets.last ?? 4.0
        if pdfView.document !== document {
            pdfView.document = document
        }
        
        // Update zoom when it changes
        let clampedZoom = min(max(zoomScale, minScale), maxScale)
        if pdfView.minScaleFactor != minScale {
            pdfView.minScaleFactor = minScale
        }
        if pdfView.maxScaleFactor != maxScale {
            pdfView.maxScaleFactor = maxScale
        }
        if abs(pdfView.scaleFactor - clampedZoom) > 0.001 {
            pdfView.scaleFactor = clampedZoom
        }
        
        if let highlightablePDF = pdfView as? HighlightablePDFView {
            highlightablePDF.highlightColor = highlightColor
        }
        
        if pdfViewRef.pdfView !== pdfView {
            pdfViewRef.pdfView = pdfView
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ActionView_Previews: PreviewProvider {
    static var previews: some View {
        ActionView(
            viewModel: NotesViewModel(),
            onDone: {}
        )
        .frame(width: 800, height: 600)
    }
}
#endif
