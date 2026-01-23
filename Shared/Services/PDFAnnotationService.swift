import Foundation
import PDFKit
import AppKit

/// Service for reading and writing PDF annotations
public class PDFAnnotationService {

    public init() {}

    // MARK: - Security: Allowed annotation keys (whitelist)

    /// Only these annotation keys are allowed to be read from PDFs
    private static let allowedAnnotationKeys: Set<String> = [
        NoteAnnotation.noteIDKey,
        NoteAnnotation.linkedHighlightKey,
        NoteAnnotation.groupIDKey
    ]

    /// Safely extract a string value from annotation, only if key is whitelisted
    private func safeAnnotationValue(for key: String, from annotation: PDFAnnotation) -> String? {
        guard Self.allowedAnnotationKeys.contains(key) else {
            return nil
        }
        guard let value = annotation.annotationKeyValues[PDFAnnotationKey(rawValue: key)] as? String else {
            return nil
        }
        // Validate the value doesn't contain potentially dangerous content
        // Only allow alphanumeric, hyphens (for UUIDs)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        guard value.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return nil
        }
        // Limit length to prevent memory issues
        guard value.count <= 100 else {
            return nil
        }
        return value
    }

    /// Safely extract UUID from annotation key
    private func safeUUID(for key: String, from annotation: PDFAnnotation) -> UUID? {
        guard let value = safeAnnotationValue(for: key, from: annotation) else {
            return nil
        }
        return UUID(uuidString: value)
    }
    
    // MARK: - Reading Annotations
    
    /// Extract all highlights with their associated notes from a PDF document
    public func extractNotesFromDocument(_ document: PDFDocument) -> [NoteAnnotation] {
        var notes: [NoteAnnotation] = []
        
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let pageNotes = extractNotesFromPage(page, pageIndex: pageIndex)
            notes.append(contentsOf: pageNotes)
        }
        
        return notes.sorted { $0.pageIndex < $1.pageIndex }
    }
    
    /// Extract notes from a single page
    private func extractNotesFromPage(_ page: PDFPage, pageIndex: Int) -> [NoteAnnotation] {
        var notes: [NoteAnnotation] = []
        let annotations = page.annotations

        // Find all highlight annotations
        let highlights = annotations.filter { $0.type == "Highlight" }

        // Group highlights by groupId to handle multi-line selections
        var groupedHighlights: [String: [PDFAnnotation]] = [:]
        var ungroupedHighlights: [PDFAnnotation] = []

        for highlight in highlights {
            if let groupId = safeAnnotationValue(for: NoteAnnotation.groupIDKey, from: highlight) {
                groupedHighlights[groupId, default: []].append(highlight)
            } else {
                ungroupedHighlights.append(highlight)
            }
        }

        // Process grouped highlights (multi-line selections)
        for (groupIdString, groupHighlights) in groupedHighlights {
            // Sort by vertical position (top to bottom) to maintain text order
            let sortedHighlights = groupHighlights.sorted { $0.bounds.origin.y > $1.bounds.origin.y }

            // Combine text from all highlights in the group
            var combinedText = ""
            for highlight in sortedHighlights {
                let text = extractTextFromHighlight(highlight, on: page)
                if !text.isEmpty {
                    if !combinedText.isEmpty {
                        combinedText += " "
                    }
                    combinedText += text
                }
            }

            // Use the first (topmost) highlight for bounds and other properties
            guard let firstHighlight = sortedHighlights.first else { continue }

            let noteText = findLinkedNoteText(for: firstHighlight, in: annotations)
            let noteID = extractNoteID(from: firstHighlight) ?? UUID()
            let groupId = UUID(uuidString: groupIdString) ?? UUID()

            let note = NoteAnnotation(
                id: noteID,
                highlightedText: combinedText,
                noteText: noteText,
                pageIndex: pageIndex,
                bounds: firstHighlight.bounds,
                highlightColor: firstHighlight.color ?? .yellow,
                groupId: groupId,
                pdfAnnotation: firstHighlight
            )

            notes.append(note)
        }

        // Process ungrouped highlights (single-line selections)
        for highlight in ungroupedHighlights {
            let highlightedText = extractTextFromHighlight(highlight, on: page)
            let noteText = findLinkedNoteText(for: highlight, in: annotations)
            let noteID = extractNoteID(from: highlight) ?? UUID()

            let note = NoteAnnotation(
                id: noteID,
                highlightedText: highlightedText,
                noteText: noteText,
                pageIndex: pageIndex,
                bounds: highlight.bounds,
                highlightColor: highlight.color ?? .yellow,
                pdfAnnotation: highlight
            )

            notes.append(note)
        }

        return notes
    }
    
    /// Extract the text content from a highlight annotation
    private func extractTextFromHighlight(_ highlight: PDFAnnotation, on page: PDFPage) -> String {
        // Try to get text from the highlight bounds
        if let selection = page.selection(for: highlight.bounds) {
            return selection.string ?? ""
        }
        
        // Fallback: try to get from annotation contents
        return highlight.contents ?? ""
    }
    
    /// Find a linked text note annotation for a highlight
    private func findLinkedNoteText(for highlight: PDFAnnotation, in annotations: [PDFAnnotation]) -> String {
        // First, check if the highlight has contents (popup note)
        if let contents = highlight.contents, !contents.isEmpty {
            // Sanitize contents - limit length and strip potentially dangerous content
            return String(contents.prefix(10000))
        }

        // Look for a text annotation linked to this highlight
        let highlightID = safeUUID(for: NoteAnnotation.noteIDKey, from: highlight)?.uuidString ?? ""

        for annotation in annotations {
            if annotation.type == "Text" || annotation.type == "FreeText" {
                if let linkedID = safeAnnotationValue(for: NoteAnnotation.linkedHighlightKey, from: annotation),
                   linkedID == highlightID {
                    return String((annotation.contents ?? "").prefix(10000))
                }
            }
        }

        return ""
    }

    /// Extract custom note ID from annotation (with validation)
    private func extractNoteID(from annotation: PDFAnnotation) -> UUID? {
        return safeUUID(for: NoteAnnotation.noteIDKey, from: annotation)
    }
    
    // MARK: - Writing Annotations
    
    /// Add or update a note for a highlight annotation
    public func saveNote(_ note: NoteAnnotation, to document: PDFDocument) -> Bool {
        guard let page = document.page(at: note.pageIndex) else { return false }
        
        // Find or create the highlight annotation
        if let highlight = findHighlightAnnotation(matching: note, on: page) {
            // Update the highlight with the note text
            updateHighlightWithNote(highlight, note: note)
            return true
        }
        
        return false
    }
    
    /// Create a new highlight with note
    public func createHighlightWithNote(
        on page: PDFPage,
        bounds: CGRect,
        text: String,
        noteText: String,
        color: NSColor = .yellow
    ) -> NoteAnnotation? {
        // Create highlight annotation
        let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        highlight.color = color
        
        // Store the note ID
        let noteID = UUID()
        highlight.setValue(noteID.uuidString, forAnnotationKey: PDFAnnotationKey(rawValue: NoteAnnotation.noteIDKey))
        
        // Store the note text in contents
        highlight.contents = noteText
        
        // Add to page
        page.addAnnotation(highlight)
        
        // Get page index
        guard let document = page.document,
              let pageIndex = (0..<document.pageCount).first(where: { document.page(at: $0) == page }) else {
            return nil
        }
        
        return NoteAnnotation(
            id: noteID,
            highlightedText: text,
            noteText: noteText,
            pageIndex: pageIndex,
            bounds: bounds,
            highlightColor: color,
            pdfAnnotation: highlight
        )
    }
    
    /// Find a highlight annotation matching the note
    private func findHighlightAnnotation(matching note: NoteAnnotation, on page: PDFPage) -> PDFAnnotation? {
        // First try to use the stored reference
        if let annotation = note.pdfAnnotation, page.annotations.contains(annotation) {
            return annotation
        }

        // Otherwise, search by ID (using safe extraction)
        for annotation in page.annotations {
            if annotation.type == "Highlight" {
                if let uuid = safeUUID(for: NoteAnnotation.noteIDKey, from: annotation),
                   uuid == note.id {
                    return annotation
                }
            }
        }

        // Finally, try to match by bounds
        for annotation in page.annotations {
            if annotation.type == "Highlight" && annotation.bounds == note.bounds {
                return annotation
            }
        }

        return nil
    }
    
    /// Update a highlight annotation with note content
    private func updateHighlightWithNote(_ highlight: PDFAnnotation, note: NoteAnnotation) {
        // Store note ID if not present
        if highlight.annotationKeyValues[NoteAnnotation.noteIDKey] == nil {
            highlight.setValue(note.id.uuidString, forAnnotationKey: PDFAnnotationKey(rawValue: NoteAnnotation.noteIDKey))
        }
        
        // Update contents with note text
        highlight.contents = note.noteText
    }
    
    /// Delete a note (removes the note text, keeps the highlight)
    public func deleteNote(_ note: NoteAnnotation, from document: PDFDocument) -> Bool {
        guard let page = document.page(at: note.pageIndex),
              let highlight = findHighlightAnnotation(matching: note, on: page) else {
            return false
        }
        
        // Clear the note text but keep the highlight
        highlight.contents = nil
        return true
    }
    
    /// Delete both the highlight and note
    public func deleteHighlightAndNote(_ note: NoteAnnotation, from document: PDFDocument) -> Bool {
        guard let page = document.page(at: note.pageIndex),
              let highlight = findHighlightAnnotation(matching: note, on: page) else {
            return false
        }
        
        page.removeAnnotation(highlight)
        return true
    }
}

