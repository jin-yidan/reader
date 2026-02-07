import SwiftUI
import PDFKit
import UniformTypeIdentifiers

/// Main content view for the standalone app with tab support
struct MainContentView: View {
    @ObservedObject var tabsViewModel: TabsViewModel
    @State private var showingSidebar = true
    @State private var showingThumbnails = false
    @State private var pdfViewRef = PDFViewReference()
    @State private var searchText = ""
    @State private var searchResults: [PDFSelection] = []
    @State private var currentSearchIndex = 0
    @State private var currentZoom: CGFloat = 1.0
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var sidebarWidth: CGFloat = 300
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1

    private var activeViewModel: NotesViewModel? {
        tabsViewModel.activeViewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar (only show if there are tabs)
            if tabsViewModel.hasOpenTabs {
                TabBarView(tabsViewModel: tabsViewModel)
                Divider()
            }
            
            // Main content
            HStack(spacing: 0) {
                // Thumbnail Sidebar (left side - page navigation)
                if activeViewModel != nil {
                    if showingThumbnails {
                        ThumbnailSidebarView(
                            document: activeViewModel?.getDocument(),
                            pdfView: pdfViewRef.pdfView,
                            isExpanded: $showingThumbnails
                        )
                    } else {
                        CollapsedThumbnailBar(isExpanded: $showingThumbnails)
                    }

                    Divider()
                }

                // PDF Viewer (center)
                pdfViewer
                    .frame(minWidth: 400)

                // Notes Sidebar with search (right side)
                if showingSidebar, let viewModel = activeViewModel {
                    // Resizable divider
                    SidebarResizeHandle(width: $sidebarWidth)

                    NotesSidebarView(
                        viewModel: viewModel,
                        searchText: $searchText,
                        searchResults: searchResults,
                        currentSearchIndex: currentSearchIndex,
                        onSearch: performSearch,
                        onNextResult: nextResult,
                        onPreviousResult: previousResult,
                        onClearSearch: clearSearch,
                        onNavigateToNote: navigateToNote,
                        onNavigateToPage: navigateToPage
                    )
                    .frame(width: sidebarWidth)
                }
            }
        }
        .toolbar {
            toolbarContent
        }
        .navigationTitle(navigationTitle)
        .navigationSubtitle(pageIndicator)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.PDFViewPageChanged)) { notification in
            updatePageInfo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showingSidebar.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSearch)) { _ in
            // Focus the search field in sidebar
            showingSidebar = true
        }
        .onChange(of: tabsViewModel.activeTabId) { newId in
            // Reset state when switching tabs
            clearSearch()
            // Sync zoom from the new active viewModel
            if let newId = newId, let vm = tabsViewModel.viewModels[newId] {
                currentZoom = vm.zoomScale
            }
            updatePageInfo()
            // Note: Page restoration is handled in PDFViewContainer.updateNSView
            // when the document changes, using the viewModel's currentPageIndex
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomChanged)) { notification in
            // Sync zoom when it changes from keyboard shortcuts
            if let zoom = notification.object as? CGFloat {
                currentZoom = zoom
                pdfViewRef.pdfView?.scaleFactor = zoom
            }
        }
        .onAppear {
            syncZoomFromViewModel()
            updatePageInfo()
        }
    }
    
    private var navigationTitle: String {
        tabsViewModel.activeTab?.title ?? "Reader"
    }

    private var pageIndicator: String {
        guard activeViewModel != nil else { return "" }
        return "Page \(currentPage) of \(totalPages)"
    }

    private func updatePageInfo() {
        guard let pdfView = pdfViewRef.pdfView,
              let document = pdfView.document,
              let activeDocument = activeViewModel?.getDocument(),
              document === activeDocument,
              let currentPDFPage = pdfView.currentPage else {
            return
        }
        let newTotalPages = document.pageCount
        let pageIndex = document.index(for: currentPDFPage)
        let newCurrentPage = pageIndex + 1

        // Only update state if values actually changed to avoid unnecessary re-renders
        if totalPages != newTotalPages {
            totalPages = newTotalPages
        }
        if currentPage != newCurrentPage {
            currentPage = newCurrentPage
        }
        activeViewModel?.currentPageIndex = pageIndex
    }

    private func syncZoomFromViewModel() {
        if let vm = activeViewModel {
            currentZoom = vm.zoomScale
        }
    }
    
    // MARK: - PDF Viewer
    
    @ViewBuilder
    private var pdfViewer: some View {
        if let viewModel = activeViewModel, let document = viewModel.getDocument() {
            PDFViewContainer(
                document: document,
                pdfViewRef: pdfViewRef,
                zoomScale: currentZoom,
                highlightColor: viewModel.highlightColor,
                pageIndex: viewModel.currentPageIndex,
                onHighlightClicked: handleHighlightClicked,
                onMultiLineHighlight: handleMultiLineHighlight,
                onDeleteHighlight: handleDeleteHighlight
            )
        } else {
            welcomeView
        }
    }
    
    private var welcomeView: some View {
        Color(nsColor: .textBackgroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.pdf, .fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            // Try PDF type first
            if provider.hasItemConformingToTypeIdentifier("com.adobe.pdf") {
                provider.loadItem(forTypeIdentifier: "com.adobe.pdf", options: nil) { item, _ in
                    if let url = item as? URL {
                        Task { @MainActor in
                            await tabsViewModel.openDocument(from: url)
                        }
                    }
                }
                return true
            }
            // Try file URL
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil),
                       url.pathExtension.lowercased() == "pdf" {
                        Task { @MainActor in
                            await tabsViewModel.openDocument(from: url)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: openDocument) {
                Image(systemName: "folder")
            }
            .help("Open PDF (⌘O)")
        }
        
        ToolbarItemGroup(placement: .primaryAction) {
            if activeViewModel != nil {
                // Zoom controls
                Button(action: zoomOut) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .disabled(currentZoom <= (NotesViewModel.zoomPresets.first ?? 0.5))
                .help("Zoom Out (⌘-)")
                .accessibilityLabel("Zoom out")

                Text("\(Int(currentZoom * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 45)
                    .accessibilityLabel("Zoom level \(Int(currentZoom * 100)) percent")

                Button(action: zoomIn) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(currentZoom >= (NotesViewModel.zoomPresets.last ?? 2.0))
                .help("Zoom In (⌘+)")
                .accessibilityLabel("Zoom in")

                // Share button with AirDrop support
                ShareButton(items: activeViewModel?.getShareItems() ?? [])
                    .disabled(activeViewModel?.getDocumentURL() == nil)
                    .help("Share (⌘E)")
                    .accessibilityLabel("Share")
            }

            // Notes sidebar toggle
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showingSidebar.toggle() } }) {
                Image(systemName: showingSidebar ? "sidebar.trailing" : "sidebar.right")
            }
            .help("Toggle Notes Sidebar (⌥⌘N)")
            .accessibilityLabel(showingSidebar ? "Hide notes sidebar" : "Show notes sidebar")
        }
    }
    
    // MARK: - Search Actions

    private func performSearch() {
        // Cancel any pending search
        searchDebounceTask?.cancel()

        guard !searchText.isEmpty else {
            clearSearch()
            return
        }

        // Debounce search by 300ms
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                executeSearch()
            }
        }
    }

    private func executeSearch() {
        guard let viewModel = activeViewModel,
              let document = viewModel.getDocument(),
              !searchText.isEmpty else {
            clearSearch()
            return
        }

        // Find all matches
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

    private func restorePagePosition(for viewModel: NotesViewModel) {
        guard let doc = viewModel.getDocument(),
              let page = doc.page(at: viewModel.currentPageIndex),
              let pdfView = pdfViewRef.pdfView else {
            return
        }
        pdfView.go(to: page)
        updatePageInfo()
    }
    
    // MARK: - Actions
    
    private func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await tabsViewModel.openDocument(from: url)
                // Update zoom for new document
                syncZoomFromViewModel()
            }
        }
    }
    
    private func zoomIn() {
        guard let nextZoom = NotesViewModel.zoomPresets.first(where: { $0 > currentZoom }) else { return }
        currentZoom = nextZoom
        activeViewModel?.zoomScale = nextZoom
        pdfViewRef.pdfView?.scaleFactor = nextZoom
    }
    
    private func zoomOut() {
        guard let prevZoom = NotesViewModel.zoomPresets.last(where: { $0 < currentZoom }) else { return }
        currentZoom = prevZoom
        activeViewModel?.zoomScale = prevZoom
        pdfViewRef.pdfView?.scaleFactor = prevZoom
    }
    
    private func handleHighlightClicked(_ annotation: PDFAnnotation, _ page: PDFPage) {
        guard let viewModel = activeViewModel,
              let document = viewModel.getDocument(),
              let pageIndex = (0..<document.pageCount).first(where: { document.page(at: $0) == page }) else {
            return
        }
        
        // Ensure sidebar is visible for editing
        if !showingSidebar {
            showingSidebar = true
        }
        
        // Find note matching this annotation using optimized lookup
        if let note = viewModel.findNote(pageIndex: pageIndex, bounds: annotation.bounds) {
            viewModel.selectNote(note)
            viewModel.startEditing(note)
        } else {
            // Check if this annotation belongs to a group (multi-line highlight)
            if let groupIdString = annotation.annotationKeyValues[NoteAnnotation.groupIDKey] as? String,
               let groupId = UUID(uuidString: groupIdString),
               let note = viewModel.findNote(byGroupId: groupId) {
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
    }
    
    private func handleMultiLineHighlight(_ highlights: [(page: PDFPage, bounds: CGRect)], _ combinedText: String, _ color: NSColor) {
        guard let viewModel = activeViewModel else { return }
        viewModel.addMultiLineHighlight(highlights: highlights, text: combinedText, color: color)
    }
    
    private func handleDeleteHighlight(_ annotation: PDFAnnotation, _ page: PDFPage) {
        guard let viewModel = activeViewModel else { return }
        
        // Use the method that handles group deletion
        viewModel.deleteHighlightByAnnotation(annotation, on: page)
    }
    
    private func navigateToNote(_ note: NoteAnnotation) {
        guard let viewModel = activeViewModel,
              let document = viewModel.getDocument(),
              let page = document.page(at: note.pageIndex),
              let pdfView = pdfViewRef.pdfView else {
            return
        }

        pdfView.go(to: page)
        let destination = PDFDestination(page: page, at: CGPoint(x: note.bounds.minX, y: note.bounds.maxY))
        pdfView.go(to: destination)
    }

    private func navigateToPage(_ pageIndex: Int) {
        guard let viewModel = activeViewModel,
              let document = viewModel.getDocument(),
              let page = document.page(at: pageIndex),
              let pdfView = pdfViewRef.pdfView else {
            return
        }

        pdfView.go(to: page)
    }
}

/// Draggable handle for resizing the sidebar
struct SidebarResizeHandle: View {
    @Binding var width: CGFloat
    @State private var isDragging = false
    @State private var dragStartWidth: CGFloat = 0

    private let minWidth: CGFloat = 250
    private let maxWidth: CGFloat = 500

    var body: some View {
        Rectangle()
            .fill(isDragging ? Color.accentColor.opacity(0.3) : Color.clear)
            .frame(width: 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartWidth = width
                        }
                        // Dragging left increases width (sidebar is on the right)
                        let newWidth = dragStartWidth - value.translation.width
                        width = min(max(newWidth, minWidth), maxWidth)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .accessibilityLabel("Resize sidebar")
            .accessibilityHint("Drag to resize the notes sidebar")
    }
}

/// Reference holder for PDFView to enable navigation
class PDFViewReference: ObservableObject {
    weak var pdfView: PDFView?
}

/// Container for PDFView with reference capture
struct PDFViewContainer: NSViewRepresentable {
    let document: PDFDocument
    let pdfViewRef: PDFViewReference
    let zoomScale: CGFloat
    let highlightColor: NSColor
    let pageIndex: Int  // Page to restore when document changes
    let onHighlightClicked: (PDFAnnotation, PDFPage) -> Void
    let onMultiLineHighlight: ([(page: PDFPage, bounds: CGRect)], String, NSColor) -> Void
    let onDeleteHighlight: (PDFAnnotation, PDFPage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onHighlightClicked: onHighlightClicked,
            onMultiLineHighlight: onMultiLineHighlight,
            onDeleteHighlight: onDeleteHighlight
        )
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = HighlightablePDFView()
        pdfView.autoScales = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = document
        pdfView.scaleFactor = zoomScale
        pdfView.highlightColor = highlightColor

        // Use coordinator to avoid closure recreation on every update
        let coordinator = context.coordinator
        pdfView.onAnnotationClicked = { [weak coordinator] annotation, page in
            if annotation.type == "Highlight" {
                coordinator?.onHighlightClicked(annotation, page)
            }
        }
        pdfView.onMultiLineHighlight = { [weak coordinator] highlights, text, color in
            coordinator?.onMultiLineHighlight(highlights, text, color)
        }
        pdfView.onDeleteHighlight = { [weak coordinator] annotation, page in
            coordinator?.onDeleteHighlight(annotation, page)
        }

        // Store reference immediately
        pdfViewRef.pdfView = pdfView

        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Update coordinator callbacks (in case they change)
        context.coordinator.onHighlightClicked = onHighlightClicked
        context.coordinator.onMultiLineHighlight = onMultiLineHighlight
        context.coordinator.onDeleteHighlight = onDeleteHighlight

        // Only update document if it actually changed
        if pdfView.document !== document {
            pdfView.document = document
            // Restore page position immediately after setting document
            if let page = document.page(at: pageIndex) {
                pdfView.go(to: page)
            }
        }

        // Only update zoom when it actually changed significantly
        if abs(pdfView.scaleFactor - zoomScale) > 0.01 {
            pdfView.scaleFactor = zoomScale
        }

        if let highlightablePDF = pdfView as? HighlightablePDFView {
            if highlightablePDF.highlightColor != highlightColor {
                highlightablePDF.highlightColor = highlightColor
            }
        }

        // Keep reference updated
        if pdfViewRef.pdfView !== pdfView {
            pdfViewRef.pdfView = pdfView
        }
    }

    class Coordinator {
        var onHighlightClicked: (PDFAnnotation, PDFPage) -> Void
        var onMultiLineHighlight: ([(page: PDFPage, bounds: CGRect)], String, NSColor) -> Void
        var onDeleteHighlight: (PDFAnnotation, PDFPage) -> Void

        init(
            onHighlightClicked: @escaping (PDFAnnotation, PDFPage) -> Void,
            onMultiLineHighlight: @escaping ([(page: PDFPage, bounds: CGRect)], String, NSColor) -> Void,
            onDeleteHighlight: @escaping (PDFAnnotation, PDFPage) -> Void
        ) {
            self.onHighlightClicked = onHighlightClicked
            self.onMultiLineHighlight = onMultiLineHighlight
            self.onDeleteHighlight = onDeleteHighlight
        }
    }
}

// MARK: - Share Button

/// Native share button that shows NSSharingServicePicker with AirDrop support
struct ShareButton: NSViewRepresentable {
    let items: [Any]

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly

        // Configure image to match SwiftUI toolbar button style
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        if let image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share") {
            button.image = image.withSymbolConfiguration(config)
        }
        button.contentTintColor = .secondaryLabelColor

        button.target = context.coordinator
        button.action = #selector(Coordinator.showSharePicker(_:))

        // Remove focus ring and set size
        button.focusRingType = .none
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.items = items
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(items: items)
    }

    class Coordinator: NSObject {
        var items: [Any]

        init(items: [Any]) {
            self.items = items
        }

        @objc func showSharePicker(_ sender: NSButton) {
            guard !items.isEmpty else { return }

            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MainContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainContentView(tabsViewModel: TabsViewModel())
            .frame(width: 900, height: 600)
    }
}
#endif
