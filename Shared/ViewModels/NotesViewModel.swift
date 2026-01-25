import Foundation
import PDFKit
import Combine
import AppKit
import UniformTypeIdentifiers

/// ViewModel managing the notes for a PDF document
@MainActor
public class NotesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var notes: [NoteAnnotation] = []
    @Published public var selectedNote: NoteAnnotation?
    @Published public var editingNote: NoteAnnotation?
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: String?
    @Published public private(set) var hasUnsavedChanges = false
    @Published public private(set) var saveStatus: SaveStatus = .idle
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var highlightColor: NSColor = .yellow

    public enum SaveStatus: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }
    
    // MARK: - Private Properties

    private let annotationService: PDFAnnotationService
    private var document: PDFDocument?
    private var documentURL: URL?
    private var autosaveTimer: Timer?
    private var saveStatusResetTask: Task<Void, Never>?
    private var hasSecurityScopedAccess = false
    private var isSaveInProgress = false
    private var pendingSave = false
    private var pendingAutosaveTask: Task<Void, Never>?

    /// Index for fast note lookup by page and bounds
    private var noteIndex: [String: NoteAnnotation] = [:]

    private func noteKey(pageIndex: Int, bounds: CGRect) -> String {
        "\(pageIndex)_\(Int(bounds.origin.x))_\(Int(bounds.origin.y))_\(Int(bounds.width))_\(Int(bounds.height))"
    }

    private func rebuildNoteIndex() {
        noteIndex = Dictionary(uniqueKeysWithValues: notes.map { note in
            (noteKey(pageIndex: note.pageIndex, bounds: note.bounds), note)
        })
    }

    /// Add a note to the index (incremental update)
    private func addToIndex(_ note: NoteAnnotation) {
        noteIndex[noteKey(pageIndex: note.pageIndex, bounds: note.bounds)] = note
    }

    /// Remove a note from the index (incremental update)
    private func removeFromIndex(_ note: NoteAnnotation) {
        noteIndex.removeValue(forKey: noteKey(pageIndex: note.pageIndex, bounds: note.bounds))
    }

    /// Fast lookup for note by page and bounds
    public func findNote(pageIndex: Int, bounds: CGRect) -> NoteAnnotation? {
        noteIndex[noteKey(pageIndex: pageIndex, bounds: bounds)]
    }

    /// Fast lookup for note by group ID
    public func findNote(byGroupId groupId: UUID) -> NoteAnnotation? {
        notes.first { $0.groupId == groupId }
    }
    
    // MARK: - Computed Properties
    
    /// Notes grouped by page number
    public var notesByPage: [(pageNumber: Int, notes: [NoteAnnotation])] {
        let grouped = Dictionary(grouping: notes) { $0.pageNumber }
        return grouped.keys.sorted().map { pageNumber in
            (pageNumber: pageNumber, notes: grouped[pageNumber] ?? [])
        }
    }
    
    /// Check if there are any notes with text
    public var hasNotes: Bool {
        notes.contains { !$0.noteText.isEmpty }
    }
    
    /// Total number of highlights
    public var highlightCount: Int {
        notes.count
    }
    
    /// Number of highlights with notes
    public var notesCount: Int {
        notes.filter { !$0.noteText.isEmpty }.count
    }
    
    /// Document title for display
    public var documentTitle: String {
        documentURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
    }
    
    // MARK: - Zoom Presets
    
    public static let zoomPresets: [CGFloat] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    
    public var zoomPercentage: Int {
        Int(zoomScale * 100)
    }
    
    // MARK: - Initialization
    
    public init(annotationService: PDFAnnotationService = PDFAnnotationService()) {
        self.annotationService = annotationService
        setupAutosave()
    }
    
    deinit {
        autosaveTimer?.invalidate()
        // Stop security-scoped access when done
        if hasSecurityScopedAccess, let url = documentURL {
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    // MARK: - Autosave
    
    private func setupAutosave() {
        // Autosave every 30 seconds if there are unsaved changes
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.autosave()
            }
        }
    }

    /// Schedule a debounced autosave (2 second delay)
    private func scheduleAutosave() {
        pendingAutosaveTask?.cancel()
        pendingAutosaveTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s debounce
            guard !Task.isCancelled else { return }
            saveDocument()
        }
    }
    
    private func autosave() {
        if hasUnsavedChanges {
            saveDocument()
        }
    }
    
    // MARK: - Document Loading
    
    /// Load a PDF document and extract notes
    public func loadDocument(from url: URL) async {
        isLoading = true
        error = nil

        // Start security-scoped access for sandboxed apps
        // Note: This returns false if the URL is not a security-scoped resource,
        // which is fine - we can still access regular file URLs
        let didStartAccess = url.startAccessingSecurityScopedResource()
        hasSecurityScopedAccess = didStartAccess

        defer {
            // Always clean up on exit if we started access and something goes wrong
            if didStartAccess && self.document == nil {
                url.stopAccessingSecurityScopedResource()
                hasSecurityScopedAccess = false
            }
        }

        do {
            // Check if file exists and is readable
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                throw NotesError.fileAccessDenied
            }

            guard let document = PDFDocument(url: url) else {
                throw NotesError.invalidDocument
            }

            self.document = document
            self.documentURL = url

            let extractedNotes = annotationService.extractNotesFromDocument(document)
            self.notes = extractedNotes
            self.rebuildNoteIndex()
            self.hasUnsavedChanges = false

            isLoading = false
        } catch let notesError as NotesError {
            self.error = notesError.localizedDescription
            isLoading = false
        } catch {
            self.error = "Failed to load document: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Load from an existing PDFDocument
    public func loadDocument(_ document: PDFDocument, url: URL? = nil) {
        self.document = document
        self.documentURL = url
        self.notes = annotationService.extractNotesFromDocument(document)
        self.rebuildNoteIndex()
        self.hasUnsavedChanges = false
    }
    
    /// Refresh notes from the current document
    public func refreshNotes() {
        guard let document = document else { return }
        notes = annotationService.extractNotesFromDocument(document)
        rebuildNoteIndex()
    }
    
    // MARK: - Highlighting
    
    /// Add a highlight to selected text
    public func addHighlight(on page: PDFPage, bounds: CGRect, text: String) {
        guard document != nil else { return }

        if let note = annotationService.createHighlightWithNote(
            on: page,
            bounds: bounds,
            text: text,
            noteText: "",
            color: highlightColor
        ) {
            notes.append(note)
            addToIndex(note)
            hasUnsavedChanges = true
            scheduleAutosave()
        }
    }
    
    /// Add multi-line highlight - creates highlight annotations for each line but one note entry
    public func addMultiLineHighlight(highlights: [(page: PDFPage, bounds: CGRect)], text: String, color: NSColor) {
        guard let document = document, !highlights.isEmpty else { return }

        // Use the first highlight's bounds and page for the note entry
        let firstHighlight = highlights[0]

        // Generate a shared group ID for all annotations
        let groupId = UUID()

        // Create highlight annotations for each line
        for highlight in highlights {
            let annotation = PDFAnnotation(bounds: highlight.bounds, forType: .highlight, withProperties: nil)
            annotation.color = color.withAlphaComponent(0.5)

            // Store the group ID in each annotation
            annotation.setValue(groupId.uuidString, forAnnotationKey: PDFAnnotationKey(rawValue: NoteAnnotation.groupIDKey))

            highlight.page.addAnnotation(annotation)
        }

        // Create one note entry with the combined text, using the first highlight's position
        guard let pageIndex = (0..<document.pageCount).first(where: { document.page(at: $0) == firstHighlight.page }) else {
            return
        }

        let note = NoteAnnotation(
            id: UUID(),
            highlightedText: text,
            noteText: "",
            pageIndex: pageIndex,
            bounds: firstHighlight.bounds,
            highlightColor: color,
            groupId: groupId
        )

        notes.append(note)
        addToIndex(note)
        hasUnsavedChanges = true
        scheduleAutosave()
    }

    // MARK: - Note Management

    /// Add a note entry for an existing highlight (when user clicks on highlight to add note)
    public func addHighlightNote(pageIndex: Int, bounds: CGRect, text: String, color: NSColor) {
        // Check if note already exists
        if notes.contains(where: { $0.pageIndex == pageIndex && $0.bounds == bounds }) {
            return
        }
        
        let note = NoteAnnotation(
            id: UUID(),
            highlightedText: text,
            noteText: "",
            pageIndex: pageIndex,
            bounds: bounds,
            highlightColor: color
        )

        notes.append(note)
        addToIndex(note)
        selectedNote = note
        editingNote = note
    }
    
    /// Start editing a note
    public func startEditing(_ note: NoteAnnotation) {
        editingNote = note
    }
    
    /// Cancel editing - removes the note if it was empty (new note that wasn't saved)
    public func cancelEditing() {
        if let note = editingNote, note.noteText.isEmpty {
            // Remove empty notes that were never saved with text
            notes.removeAll { $0.id == note.id }
            removeFromIndex(note)
        }
        editingNote = nil
        selectedNote = nil
    }
    
    /// Save changes to a note
    public func saveNote(_ note: NoteAnnotation, newText: String) {
        guard let document = document else { return }
        
        var updatedNote = note
        updatedNote.noteText = newText
        
        // Update the annotation contents
        if let page = document.page(at: note.pageIndex) {
            for annotation in page.annotations {
                if annotation.type == "Highlight" && annotation.bounds == note.bounds {
                    annotation.contents = newText
                    break
                }
            }
        }
        
        // Update local state
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = updatedNote
        }

        hasUnsavedChanges = true
        scheduleAutosave()
        editingNote = nil
    }

    /// Delete a note (keeps the highlight)
    public func deleteNote(_ note: NoteAnnotation) {
        guard let document = document else { return }

        if annotationService.deleteNote(note, from: document) {
            // Update local state
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                var updatedNote = notes[index]
                updatedNote.noteText = ""
                notes[index] = updatedNote
            }

            hasUnsavedChanges = true
            scheduleAutosave()
        }
    }
    
    /// Delete both highlight and note (including all highlights in the same group)
    public func deleteHighlight(_ note: NoteAnnotation) {
        guard let document = document else { return }

        // Delete all annotations with the same group ID
        deleteAnnotationsInGroup(groupId: note.groupId, from: document)

        // Remove from local state
        removeFromIndex(note)
        notes.removeAll { $0.id == note.id }
        hasUnsavedChanges = true
        scheduleAutosave()
    }
    
    /// Delete all annotations that share the same group ID
    private func deleteAnnotationsInGroup(groupId: UUID, from document: PDFDocument) {
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            // Collect annotations to remove (can't modify while iterating)
            var annotationsToRemove: [PDFAnnotation] = []

            for annotation in page.annotations {
                if annotation.type == "Highlight" {
                    // Check if this annotation belongs to the group
                    if let groupIdString = annotation.annotationKeyValues[PDFAnnotationKey(rawValue: NoteAnnotation.groupIDKey)] as? String,
                       groupIdString == groupId.uuidString {
                        annotationsToRemove.append(annotation)
                    }
                    // Also check by bounds for single highlights (no group ID)
                    else if annotation.annotationKeyValues[PDFAnnotationKey(rawValue: NoteAnnotation.groupIDKey)] == nil {
                        // Check if it matches any note with this groupId (using tolerance)
                        let annotationBounds = annotation.bounds
                        if notes.contains(where: { $0.groupId == groupId && boundsMatch($0.bounds, annotationBounds) }) {
                            annotationsToRemove.append(annotation)
                        }
                    }
                }
            }

            // Remove the annotations
            for annotation in annotationsToRemove {
                page.removeAnnotation(annotation)
            }
        }
    }
    
    /// Select a note (for navigation)
    public func selectNote(_ note: NoteAnnotation) {
        selectedNote = note
    }
    
    // MARK: - Document Saving

    /// Save the document to disk (performs file I/O on background thread)
    public func saveDocument() {
        guard let document = document, let url = documentURL else { return }

        // Prevent concurrent saves - queue the request instead
        if isSaveInProgress {
            pendingSave = true
            return
        }

        isSaveInProgress = true
        saveStatus = .saving

        // Get data on main thread (PDFDocument not thread-safe)
        guard let documentData = document.dataRepresentation() else {
            isSaveInProgress = false
            saveStatus = .failed("Could not generate PDF data")
            return
        }

        // Write on background thread to avoid blocking UI
        Task.detached(priority: .utility) { [weak self] in
            var success = false
            var saveError: String?

            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinatorError: NSError?

            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { newURL in
                do {
                    try documentData.write(to: newURL, options: .atomic)
                    success = true
                } catch let writeError {
                    saveError = writeError.localizedDescription
                }
            }

            if let coordinatorError = coordinatorError {
                saveError = coordinatorError.localizedDescription
            }

            await MainActor.run { [weak self] in
                self?.handleSaveCompletion(succeeded: success, errorMessage: saveError)
            }
        }
    }

    /// Handle save completion (called on main actor after background save)
    private func handleSaveCompletion(succeeded: Bool, errorMessage: String?) {
        isSaveInProgress = false

        if succeeded {
            hasUnsavedChanges = false
            saveStatus = .saved

            // Reset status after 2 seconds
            saveStatusResetTask?.cancel()
            saveStatusResetTask = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                if case .saved = self.saveStatus {
                    self.saveStatus = .idle
                }
            }
        } else {
            let reason = errorMessage ?? "Unknown error"
            saveStatus = .failed(reason)
            error = "Failed to save: \(reason)"
        }

        // If there was a pending save request, execute it now
        if pendingSave {
            pendingSave = false
            // Use slight delay to prevent tight loop
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                saveDocument()
            }
        }
    }
    
    /// Get the PDF page for a note
    public func getPage(for note: NoteAnnotation) -> PDFPage? {
        return document?.page(at: note.pageIndex)
    }
    
    /// Get the current document
    public func getDocument() -> PDFDocument? {
        return document
    }
    
    /// Get document URL
    public func getDocumentURL() -> URL? {
        return documentURL
    }

    /// Save document to a new URL (for Save As / Rename)
    public func saveDocumentAs(to newURL: URL) -> Bool {
        guard let doc = document else { return false }

        // Write to new location
        let success = doc.write(to: newURL)
        if success {
            // Update internal references
            documentURL = newURL
            _ = newURL.startAccessingSecurityScopedResource()

            // Reload from new location
            if let newDocument = PDFDocument(url: newURL) {
                document = newDocument
            }
            hasUnsavedChanges = false
        }
        return success
    }

    /// Rename the document file
    public func renameDocument(to newName: String) -> Bool {
        guard let currentURL = documentURL else { return false }

        // Security: Validate newName to prevent path traversal
        let sanitizedName = newName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "..", with: "")

        // Ensure name is not empty after sanitization
        guard !sanitizedName.isEmpty else { return false }

        // Ensure name doesn't start with a dot (hidden file)
        let finalName = sanitizedName.hasPrefix(".") ? String(sanitizedName.dropFirst()) : sanitizedName
        guard !finalName.isEmpty else { return false }

        let directory = currentURL.deletingLastPathComponent()
        let newURL = directory.appendingPathComponent(finalName).appendingPathExtension("pdf")

        // Don't rename if same name
        if currentURL == newURL { return true }

        // Check if destination already exists
        if FileManager.default.fileExists(atPath: newURL.path) {
            error = "A file with this name already exists"
            return false
        }

        // Use security-scoped access for sandboxed operations
        let didStartAccess = currentURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                currentURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Write document to new location (works better with sandbox than moveItem)
            guard let doc = document else { return false }
            let success = doc.write(to: newURL)
            guard success else {
                self.error = "Failed to save to new location"
                return false
            }

            // Delete old file
            try FileManager.default.removeItem(at: currentURL)

            // Update the URL reference
            documentURL = newURL

            // Start accessing the new URL
            _ = newURL.startAccessingSecurityScopedResource()

            // Reload from new location
            if let newDocument = PDFDocument(url: newURL) {
                document = newDocument
            }
            return true
        } catch {
            self.error = "Failed to rename: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Delete highlight by annotation (called from right-click menu)
    public func deleteHighlightByAnnotation(_ annotation: PDFAnnotation, on page: PDFPage) {
        guard let document = document else { return }

        // Check if this annotation has a group ID
        if let groupIdString = annotation.annotationKeyValues[PDFAnnotationKey(rawValue: NoteAnnotation.groupIDKey)] as? String,
           let groupId = UUID(uuidString: groupIdString) {
            // Delete all annotations in this group
            deleteAnnotationsInGroup(groupId: groupId, from: document)

            // Remove the note entry if it exists
            let notesToRemove = notes.filter { $0.groupId == groupId }
            for note in notesToRemove {
                removeFromIndex(note)
            }
            notes.removeAll { $0.groupId == groupId }
        } else {
            // Single annotation - just remove it
            page.removeAnnotation(annotation)

            // Find and remove matching note
            if let pageIndex = (0..<document.pageCount).first(where: { document.page(at: $0) == page }) {
                // Try multiple matching strategies
                let annotationBounds = annotation.bounds
                let notesToRemove = notes.filter { note in
                    guard note.pageIndex == pageIndex else { return false }
                    // Match by stored annotation reference
                    if note.pdfAnnotation === annotation { return true }
                    // Match by bounds with tolerance
                    return boundsMatch(note.bounds, annotationBounds)
                }
                for note in notesToRemove {
                    removeFromIndex(note)
                }
                notes.removeAll { note in
                    notesToRemove.contains { $0.id == note.id }
                }
            }
        }

        hasUnsavedChanges = true
        scheduleAutosave()
    }

    /// Compare bounds with tolerance for floating-point precision
    private func boundsMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        let tolerance: CGFloat = 2.0
        return abs(a.origin.x - b.origin.x) < tolerance &&
               abs(a.origin.y - b.origin.y) < tolerance &&
               abs(a.width - b.width) < tolerance &&
               abs(a.height - b.height) < tolerance
    }

    // MARK: - Save As

    /// Save document to a new location
    public func saveDocumentAs() {
        guard let document = document else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = documentTitle + ".pdf"
        savePanel.canCreateDirectories = true

        if savePanel.runModal() == .OK, let url = savePanel.url {
            if document.write(to: url) {
                // Update to new location
                documentURL = url
                hasUnsavedChanges = false
                saveStatus = .saved

                // Reset status after delay
                saveStatusResetTask?.cancel()
                saveStatusResetTask = Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        if case .saved = self.saveStatus {
                            self.saveStatus = .idle
                        }
                    }
                }
            } else {
                error = "Failed to save document"
                saveStatus = .failed("Failed to save document")
            }
        }
    }

    // MARK: - Export Notes

    /// Export notes to markdown file
    public func exportNotes() {
        guard !notes.isEmpty else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.plainText]
        savePanel.nameFieldStringValue = "\(documentTitle)-notes.md"
        savePanel.canCreateDirectories = true

        if savePanel.runModal() == .OK, let url = savePanel.url {
            var content = "# Notes: \(documentTitle)\n\n"
            for page in notesByPage {
                content += "## Page \(page.pageNumber)\n\n"
                for note in page.notes {
                    content += "> \(note.highlightedText)\n\n"
                    if !note.noteText.isEmpty {
                        content += "\(note.noteText)\n\n"
                    }
                }
            }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

}

// MARK: - Errors

enum NotesError: LocalizedError {
    case invalidDocument
    case saveFailed
    case fileAccessDenied
    case saveInProgress

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            return "Could not open the PDF document."
        case .saveFailed:
            return "Could not save the document."
        case .fileAccessDenied:
            return "Cannot access this file. Check permissions."
        case .saveInProgress:
            return "A save operation is already in progress."
        }
    }
}
