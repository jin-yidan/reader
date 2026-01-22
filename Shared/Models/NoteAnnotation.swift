import Foundation
import PDFKit
import AppKit

/// Represents a note attached to a PDF highlight
public struct NoteAnnotation: Identifiable, Equatable {
    public let id: UUID
    public let highlightedText: String
    public var noteText: String
    public let pageIndex: Int
    public let bounds: CGRect
    public let highlightColor: NSColor
    public let groupId: UUID  // Links multi-line highlights together
    public weak var pdfAnnotation: PDFAnnotation?
    
    public init(
        id: UUID = UUID(),
        highlightedText: String,
        noteText: String = "",
        pageIndex: Int,
        bounds: CGRect,
        highlightColor: NSColor = .yellow,
        groupId: UUID? = nil,
        pdfAnnotation: PDFAnnotation? = nil
    ) {
        self.id = id
        self.highlightedText = highlightedText
        self.noteText = noteText
        self.pageIndex = pageIndex
        self.bounds = bounds
        self.highlightColor = highlightColor
        self.groupId = groupId ?? id  // Default to id if no group
        self.pdfAnnotation = pdfAnnotation
    }
    
    /// Truncated highlight text for display (first 100 characters)
    public var displayText: String {
        if highlightedText.count <= 100 {
            return highlightedText
        }
        return String(highlightedText.prefix(100)) + "..."
    }
    
    /// Human-readable page number (1-indexed)
    public var pageNumber: Int {
        pageIndex + 1
    }
    
    public static func == (lhs: NoteAnnotation, rhs: NoteAnnotation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - PDF Annotation Keys
extension NoteAnnotation {
    /// Custom key used to store the note ID in PDF annotation
    static let noteIDKey = "/PreviewNotesID"
    
    /// Custom key used to link note annotation to highlight
    static let linkedHighlightKey = "/PreviewNotesLinkedHighlight"
    
    /// Custom key for group ID (links multi-line highlights)
    static let groupIDKey = "/PreviewNotesGroupID"
}
