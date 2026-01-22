import Foundation
import PDFKit

/// Represents an open document tab
public struct DocumentTab: Identifiable, Equatable {
    public let id: UUID
    public var url: URL?
    public var title: String

    public init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
    }

    /// Update the tab after a rename operation
    public mutating func updateAfterRename(newURL: URL) {
        self.url = newURL
        self.title = newURL.deletingPathExtension().lastPathComponent
    }

    public static func == (lhs: DocumentTab, rhs: DocumentTab) -> Bool {
        lhs.id == rhs.id
    }
}

