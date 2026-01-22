import SwiftUI
import PDFKit

/// Sidebar view displaying PDF page thumbnails
public struct ThumbnailSidebarView: View {
    let document: PDFDocument?
    let pdfView: PDFView?
    @Binding var isExpanded: Bool
    
    public init(document: PDFDocument?, pdfView: PDFView?, isExpanded: Binding<Bool>) {
        self.document = document
        self.pdfView = pdfView
        self._isExpanded = isExpanded
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with collapse button
            HStack {
                // Placeholder for symmetry
                Color.clear.frame(width: 16, height: 16)

                Spacer()

                Text("Pages")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Collapse Thumbnails")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            
            Divider()
            
            // Thumbnail view
            if let document = document {
                PDFThumbnailViewWrapper(document: document, pdfView: pdfView)
            } else {
                emptyState
            }
        }
        .frame(width: 120)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No document")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

/// Collapsed thumbnail bar (just a button to expand)
public struct CollapsedThumbnailBar: View {
    @Binding var isExpanded: Bool
    
    public var body: some View {
        VStack {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                VStack(spacing: 4) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                    Text("Pages")
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary)
                .frame(width: 40)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .help("Show Thumbnails")

            Spacer()
        }
        .frame(width: 40)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// NSViewRepresentable wrapper for PDFThumbnailView
struct PDFThumbnailViewWrapper: NSViewRepresentable {
    let document: PDFDocument
    let pdfView: PDFView?
    
    func makeNSView(context: Context) -> PDFThumbnailView {
        let thumbnailView = PDFThumbnailView()
        thumbnailView.thumbnailSize = CGSize(width: 80, height: 100)
        thumbnailView.backgroundColor = .windowBackgroundColor
        thumbnailView.pdfView = pdfView
        return thumbnailView
    }
    
    func updateNSView(_ thumbnailView: PDFThumbnailView, context: Context) {
        // Update pdfView reference if it changes
        if thumbnailView.pdfView !== pdfView {
            thumbnailView.pdfView = pdfView
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ThumbnailSidebarView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 0) {
            Color.gray.opacity(0.3)
                .frame(width: 300)
            
            Divider()
            
            ThumbnailSidebarView(document: nil, pdfView: nil, isExpanded: .constant(true))
        }
        .frame(height: 400)
    }
}
#endif
