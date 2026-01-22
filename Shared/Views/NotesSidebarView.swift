import SwiftUI
import PDFKit

/// Sidebar view displaying all notes organized by page with search at top
public struct NotesSidebarView: View {
    @ObservedObject var viewModel: NotesViewModel
    @Binding var searchText: String
    let searchResults: [PDFSelection]
    let currentSearchIndex: Int
    let onSearch: () -> Void
    let onNextResult: () -> Void
    let onPreviousResult: () -> Void
    let onClearSearch: () -> Void
    let onNavigateToNote: (NoteAnnotation) -> Void
    let onNavigateToPage: ((Int) -> Void)?

    @State private var focusedNoteIndex: Int?

    public init(
        viewModel: NotesViewModel,
        searchText: Binding<String>,
        searchResults: [PDFSelection],
        currentSearchIndex: Int,
        onSearch: @escaping () -> Void,
        onNextResult: @escaping () -> Void,
        onPreviousResult: @escaping () -> Void,
        onClearSearch: @escaping () -> Void,
        onNavigateToNote: @escaping (NoteAnnotation) -> Void,
        onNavigateToPage: ((Int) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self._searchText = searchText
        self.searchResults = searchResults
        self.currentSearchIndex = currentSearchIndex
        self.onSearch = onSearch
        self.onNextResult = onNextResult
        self.onPreviousResult = onPreviousResult
        self.onClearSearch = onClearSearch
        self.onNavigateToNote = onNavigateToNote
        self.onNavigateToPage = onNavigateToPage
    }
    
    /// Notes that have text OR are currently being edited (to allow adding notes to highlights)
    private var visibleNotes: [NoteAnnotation] {
        viewModel.notes.filter { note in
            !note.noteText.isEmpty || viewModel.editingNote?.id == note.id
        }
    }
    
    /// Visible notes grouped by page
    private var visibleNotesByPage: [(pageNumber: Int, notes: [NoteAnnotation])] {
        let grouped = Dictionary(grouping: visibleNotes) { $0.pageNumber }
        return grouped.keys.sorted().map { pageNumber in
            (pageNumber: pageNumber, notes: grouped[pageNumber] ?? [])
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search bar at top
            searchBar
            
            Divider()
            
            // Stats header
            header
            
            Divider()
            
            if viewModel.isLoading {
                loadingView
            } else if visibleNotes.isEmpty {
                emptyState
            } else {
                notesList
            }
        }
        .frame(minWidth: 250)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField("Search in document...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        onSearch()
                    }
                    .accessibilityLabel("Search in document")
                
                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.15)) {
                            searchText = ""
                            onClearSearch()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            if !searchResults.isEmpty {
                HStack(spacing: 4) {
                    Text("\(currentSearchIndex + 1)/\(searchResults.count)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 35)
                    
                    Button(action: onPreviousResult) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous search result")

                    Button(action: onNextResult) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next search result")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Notes")
                .font(.system(size: 14, weight: .semibold))

            // Save status indicator
            saveStatusView

            Spacer()

            Text("\(viewModel.notesCount) notes")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var saveStatusView: some View {
        Group {
            switch viewModel.saveStatus {
            case .idle:
                EmptyView()
            case .saving:
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Saving...")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Saving document")
            case .saved:
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("Saved")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
                .accessibilityLabel("Document saved")
            case .failed(let message):
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Text("Save failed")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
                .help(message)
                .accessibilityLabel("Save failed: \(message)")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.saveStatus)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Loading annotations...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No notes yet")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Click on a highlight to add notes.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Notes List

    /// Flat list of visible notes for keyboard navigation
    private var flatVisibleNotes: [NoteAnnotation] {
        visibleNotesByPage.flatMap { $0.notes }
    }

    private var notesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                    ForEach(visibleNotesByPage, id: \.pageNumber) { pageGroup in
                        Section {
                            ForEach(Array(pageGroup.notes.enumerated()), id: \.element.id) { index, note in
                                let globalIndex = flatVisibleNotes.firstIndex(where: { $0.id == note.id }) ?? 0
                                NoteCardView(
                                    note: note,
                                    isSelected: viewModel.selectedNote?.id == note.id,
                                    isEditing: viewModel.editingNote?.id == note.id,
                                    onTap: {
                                        focusedNoteIndex = globalIndex
                                        viewModel.selectNote(note)
                                        onNavigateToNote(note)
                                    },
                                    onEdit: {
                                        viewModel.startEditing(note)
                                    },
                                    onDelete: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.deleteHighlight(note)
                                        }
                                    },
                                    onSave: { newText in
                                        viewModel.saveNote(note, newText: newText)
                                    },
                                    onCancel: {
                                        viewModel.cancelEditing()
                                    }
                                )
                                .id(note.id)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.95))
                                ))
                                .accessibilityLabel("Note on page \(note.pageNumber): \(note.displayText)")
                            }
                        } header: {
                            pageHeader(pageGroup.pageNumber)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .animation(.easeInOut(duration: 0.2), value: viewModel.notes.count)
            }
            .modifier(KeyboardNavigationModifier(
                onDownArrow: { navigateToNextNote(proxy: proxy) },
                onUpArrow: { navigateToPreviousNote(proxy: proxy) },
                onReturn: {
                    if let index = focusedNoteIndex, index < flatVisibleNotes.count {
                        let note = flatVisibleNotes[index]
                        viewModel.startEditing(note)
                    }
                }
            ))
            .onChange(of: viewModel.selectedNote?.id) { noteId in
                // Scroll to selected note when it changes (e.g., from clicking highlight in PDF)
                if let noteId = noteId {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(noteId, anchor: .center)
                    }
                }
            }
        }
    }

    private func navigateToNextNote(proxy: ScrollViewProxy) {
        let notes = flatVisibleNotes
        guard !notes.isEmpty else { return }

        let newIndex: Int
        if let current = focusedNoteIndex {
            newIndex = min(current + 1, notes.count - 1)
        } else {
            newIndex = 0
        }

        focusedNoteIndex = newIndex
        let note = notes[newIndex]
        viewModel.selectNote(note)
        onNavigateToNote(note)

        withAnimation {
            proxy.scrollTo(note.id, anchor: .center)
        }
    }

    private func navigateToPreviousNote(proxy: ScrollViewProxy) {
        let notes = flatVisibleNotes
        guard !notes.isEmpty else { return }

        let newIndex: Int
        if let current = focusedNoteIndex {
            newIndex = max(current - 1, 0)
        } else {
            newIndex = notes.count - 1
        }

        focusedNoteIndex = newIndex
        let note = notes[newIndex]
        viewModel.selectNote(note)
        onNavigateToNote(note)

        withAnimation {
            proxy.scrollTo(note.id, anchor: .center)
        }
    }
    
    private func pageHeader(_ pageNumber: Int) -> some View {
        Button(action: {
            // Navigate to page (pageNumber is 1-indexed, pageIndex is 0-indexed)
            onNavigateToPage?(pageNumber - 1)
        }) {
            HStack(spacing: 4) {
                Text("Page \(pageNumber)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Go to page \(pageNumber)")
        .accessibilityLabel("Go to page \(pageNumber)")
    }
}

// MARK: - Keyboard Navigation Modifier

/// ViewModifier that adds keyboard navigation with availability check
struct KeyboardNavigationModifier: ViewModifier {
    let onDownArrow: () -> Void
    let onUpArrow: () -> Void
    let onReturn: () -> Void

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content
                .onKeyPress(.downArrow) {
                    onDownArrow()
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    onUpArrow()
                    return .handled
                }
                .onKeyPress(.return) {
                    onReturn()
                    return .handled
                }
        } else {
            // Fallback for older macOS versions - keyboard nav not available
            content
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NotesSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        NotesSidebarView(
            viewModel: NotesViewModel(),
            searchText: .constant(""),
            searchResults: [],
            currentSearchIndex: 0,
            onSearch: {},
            onNextResult: {},
            onPreviousResult: {},
            onClearSearch: {},
            onNavigateToNote: { _ in }
        )
    }
}
#endif
